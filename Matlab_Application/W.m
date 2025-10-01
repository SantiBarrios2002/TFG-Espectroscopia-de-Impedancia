function z = W(p, f)
% Warburg Short (finite-length diffusion with reflective boundary)
% Z_Ws = (Aw/sqrt(w)) * tanh(B*sqrt(jw)) / sqrt(jw)
% p(1) = Aw: Warburg coefficient
% p(2) = B: Diffusion time constant related parameter
omega = 2*pi*f;
Aw = p(1);
B = p(2);
z = (Aw ./ sqrt(omega)) .* tanh(B .* sqrt(1i*omega)) ./ sqrt(1i*omega);
end
