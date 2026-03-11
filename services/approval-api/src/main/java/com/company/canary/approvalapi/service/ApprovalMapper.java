package com.company.canary.approvalapi.service;

import com.company.canary.approvalapi.api.ApprovalResponse;
import com.company.canary.approvalapi.domain.ApprovalRequestEntity;
import org.springframework.stereotype.Component;

@Component
public class ApprovalMapper {

    public ApprovalResponse toResponse(ApprovalRequestEntity entity) {
        return new ApprovalResponse(
                entity.getId(),
                entity.getCluster(),
                entity.getNamespace(),
                entity.getCanaryName(),
                entity.getRevision(),
                entity.getStepType(),
                entity.getStatus(),
                entity.getRequestedBy(),
                entity.getRequestedAt(),
                entity.getExpiresAt(),
                entity.getDecisionBy(),
                entity.getDecisionReason(),
                entity.getDecidedAt(),
                entity.getSnowTaskId()
        );
    }
}
