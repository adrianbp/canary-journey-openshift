package com.company.canary.contracts;

public record HookDecisionResponse(
        ApprovalStatus status,
        String reason
) {
}
