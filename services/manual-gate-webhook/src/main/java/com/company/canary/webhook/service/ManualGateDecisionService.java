package com.company.canary.webhook.service;

import com.company.canary.contracts.ApprovalStatus;
import com.company.canary.contracts.FlaggerHookRequest;
import com.company.canary.contracts.HookDecisionResponse;
import com.company.canary.contracts.StepType;
import com.company.canary.webhook.client.ApprovalApiClient;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
public class ManualGateDecisionService {

    private final ApprovalApiClient approvalApiClient;

    public ManualGateDecisionService(ApprovalApiClient approvalApiClient) {
        this.approvalApiClient = approvalApiClient;
    }

    public DecisionResult evaluate(FlaggerHookRequest request) {
        Map<String, String> metadata = request.metadata() == null ? Map.of() : request.metadata();

        String cluster = metadata.getOrDefault("cluster", "eks-main");
        String revision = metadata.getOrDefault("revision", request.checksum());
        StepType stepType = mapPhaseToStepType(request.phase());

        HookDecisionResponse decision = approvalApiClient.resolve(
                cluster,
                request.namespace(),
                request.name(),
                revision,
                stepType
        );

        if (decision.status() == ApprovalStatus.APPROVED) {
            return new DecisionResult(HttpStatus.OK, "approved");
        }
        if (decision.status() == ApprovalStatus.REQUESTED) {
            return new DecisionResult(HttpStatus.CONFLICT, "pending");
        }
        if (decision.status() == ApprovalStatus.REJECTED || decision.status() == ApprovalStatus.EXPIRED) {
            return new DecisionResult(HttpStatus.PRECONDITION_FAILED, "rejected_or_expired");
        }

        return new DecisionResult(HttpStatus.PRECONDITION_FAILED, "unsupported_status");
    }

    static StepType mapPhaseToStepType(String phase) {
        if (phase == null) {
            return StepType.CONFIRM_PROMOTION;
        }
        return switch (phase.toLowerCase()) {
            case "confirm-rollout" -> StepType.CONFIRM_ROLLOUT;
            case "confirm-promotion" -> StepType.CONFIRM_PROMOTION;
            case "rollback" -> StepType.ROLLBACK;
            default -> StepType.ROLLOUT;
        };
    }

    public record DecisionResult(HttpStatus status, String message) {
    }
}
