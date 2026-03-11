package com.company.canary.approvalapi.api;

import com.company.canary.contracts.ApprovalStatus;
import com.company.canary.contracts.StepType;

import java.time.OffsetDateTime;
import java.util.UUID;

public record ApprovalResponse(
        UUID id,
        String cluster,
        String namespace,
        String canaryName,
        String revision,
        StepType stepType,
        ApprovalStatus status,
        String requestedBy,
        OffsetDateTime requestedAt,
        OffsetDateTime expiresAt,
        String decisionBy,
        String decisionReason,
        OffsetDateTime decidedAt,
        String snowTaskId
) {
}
