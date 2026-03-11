package com.company.canary.approvalapi.api;

import jakarta.validation.constraints.NotBlank;

public record ApprovalActionRequest(
        @NotBlank String actor,
        String reason,
        @NotBlank String idempotencyKey
) {
}
