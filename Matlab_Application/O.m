function z = O(p, f)
% Warburg Open (finite-length diffusion with transmissive boundary)
% Z_Wo = (Aw/sqrt(w)) * coth(B*sqrt(jw)) / sqrt(jw)
% p(1) = Aw: Warburg coefficient
% p(2) = B: Diffusion time constant related parameter
omega = 2*pi*f;
Aw = p(1);
B = p(2);
z = (Aw ./ sqrt(omega)) .* coth(B .* sqrt(1i*omega)) ./ sqrt(1i*omega);
end
