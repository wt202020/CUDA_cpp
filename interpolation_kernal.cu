#include <torch/extension.h>


template <typename scalar_t>
__global__ void trilinear_fw_kernel(
    const torch::PackedTensorAccessor<scalar_t, 3, torch::RestrictPtrTraits, size_t> feats,
    const torch::PackedTensorAccessor<scalar_t, 2, torch::RestrictPtrTraits, size_t> point,
    torch::PackedTensorAccessor<scalar_t, 2, torch::RestrictPtrTraits, size_t> feat_interp
)
{
    const int N = feats.size(0);
    const int F = feats.size(2);

    const int n = blockIdx.x * blockDim.x + threadIdx.x;
    const int f = blockIdx.y * blockDim.y + threadIdx.y;

    if (n < N && f < F)
    {
        const scalar_t u = (point[n][0] + 1) / 2;
        const scalar_t v = (point[n][1] + 1) / 2;
        const scalar_t w = (point[n][2] + 1) / 2;

        const scalar_t a = (1-v) * (1-w);
        const scalar_t b = (1-v) * w;
        const scalar_t c = v * (1-w);
        const scalar_t d = 1 - a - b - c;

        feat_interp[n][f] = (1-u) * (a * feats[n][0][f] + b * feats[n][1][f] + c * feats[n][2][f] + d * feats[n][3][f]) + 
                            u * (a * feats[n][4][f] + b * feats[n][5][f] + c * feats[n][6][f] + d * feats[n][7][f]);
    }
}

torch::Tensor trilinear_fw_cu(
    torch::Tensor feats,
    torch::Tensor point
)
{ 
    const int N = feats.size(0);
    const int F = feats.size(2);

    torch::Tensor feat_interp = torch::zeros({N, F}, feats.options());

    const dim3 threads(16, 16);
    const dim3 blocks((N + threads.x - 1) / threads.x, (F + threads.y - 1) / threads.y);

    AT_DISPATCH_FLOATING_TYPES(feats.type(), "trilinear_fw_cu", 
    ([&] {
        trilinear_fw_kernel<scalar_t><<<blocks, threads>>>(      //scalar_t represent the type of the input tensor that maybe unkonwn
            feats.packed_accessor<scalar_t, 3, torch::RestrictPtrTraits, size_t>(), 
            point.packed_accessor<scalar_t, 2, torch::RestrictPtrTraits, size_t>(),
            feat_interp.packed_accessor<scalar_t, 2, torch::RestrictPtrTraits, size_t>()
        );
    }));

    return feat_interp;
}