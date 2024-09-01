import torch
import cppcuda_tutorial

feats = torch.ones(2)
points = torch.zeros(2)

out = cppcuda_tutorial.trilinear_interpolation(feats, points)

print(out)