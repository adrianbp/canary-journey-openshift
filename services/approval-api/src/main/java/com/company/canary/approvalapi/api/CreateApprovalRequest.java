package com.company.canary.approvalapi.api;

import com.company.canary.contracts.StepType;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record CreateApprovalRequest(
        @NotBlank String cluster,
        @NotBlank String namespace,
        @NotBlank String canaryName,
        @NotBlank String revision,
        @NotNull StepType stepType,
        @NotBlank String requestedBy,
        @Min(1) int ttlMinutes,
        String snowTaskId
) {
}
