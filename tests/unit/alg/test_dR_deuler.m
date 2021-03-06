function test_dR_deuler
    euler = [-0.284978769837712;
              0.262166472859945;
             -1.516780216333023];

    R = reshape(alg.euler2R(euler), [], 1);

    % Get finite difference approximation
    delta = 1e-5;
    dR_deuler = zeros(9, 3);
    for i = 1:3
        euler_delta = euler;
        euler_delta(i) = euler(i) + delta;
        R_delta = reshape(alg.euler2R(euler_delta), [], 1);
        dR_deuler(:, i) = (R_delta-R)./delta;
    end

    % Assert
    assert(all(all(abs(dR_deuler - alg.dR_deuler(euler)) < 1e-4)));
end
