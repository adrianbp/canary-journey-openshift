package com.company.canary.approvalapi.api;

import com.company.canary.contracts.StepType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record ResolveDecisionRequest(
        @NotBlank String cluster,
        @NotBlank String namespace,
        @NotBlank String canaryName,
        @NotBlank String revision,
        @NotNull StepType stepType
) {
}
