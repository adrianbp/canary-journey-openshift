package com.company.canary.webhook.service;

import com.company.canary.contracts.ApprovalStatus;
import com.company.canary.contracts.FlaggerHookRequest;
import com.company.canary.contracts.HookDecisionResponse;
import com.company.canary.webhook.client.ApprovalApiClient;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ManualGateDecisionServiceTest {

    @Mock
    private ApprovalApiClient approvalApiClient;

    @Test
    void shouldReturn409WhenPending() {
        when(approvalApiClient.resolve(anyString(), anyString(), anyString(), anyString(), any()))
                .thenReturn(new HookDecisionResponse(ApprovalStatus.REQUESTED, "pending"));

        ManualGateDecisionService service = new ManualGateDecisionService(approvalApiClient);
        ManualGateDecisionService.DecisionResult result = service.evaluate(new FlaggerHookRequest(
                "payments-api",
                "team-a",
                "confirm-promotion",
                "rev-1",
                Map.of("cluster", "eks-main", "revision", "rev-1")
        ));

        assertThat(result.status().value()).isEqualTo(409);
    }

    @Test
    void shouldMapRollbackPhaseToRollbackStepType() {
        when(approvalApiClient.resolve(anyString(), anyString(), anyString(), anyString(), any()))
                .thenReturn(new HookDecisionResponse(ApprovalStatus.REQUESTED, "pending"));

        ManualGateDecisionService service = new ManualGateDecisionService(approvalApiClient);
        service.evaluate(new FlaggerHookRequest(
                "payments-api",
                "team-a",
                "rollback",
                "rev-1",
                Map.of("cluster", "eks-main", "revision", "rev-1")
        ));

        ArgumentCaptor<com.company.canary.contracts.StepType> captor =
                ArgumentCaptor.forClass(com.company.canary.contracts.StepType.class);
        verify(approvalApiClient).resolve(anyString(), anyString(), anyString(), anyString(), captor.capture());
        assertThat(captor.getValue()).isEqualTo(com.company.canary.contracts.StepType.ROLLBACK);
    }
}
