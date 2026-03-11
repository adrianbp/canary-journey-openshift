package com.company.canary.webhook.client;

import com.company.canary.contracts.HookDecisionResponse;
import com.company.canary.contracts.StepType;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Component
public class ApprovalApiClient {

    private final RestClient restClient;

    public ApprovalApiClient(RestClient approvalApiRestClient) {
        this.restClient = approvalApiRestClient;
    }

    public HookDecisionResponse resolve(
            String cluster,
            String namespace,
            String canaryName,
            String revision,
            StepType stepType
    ) {
        ResolveDecisionPayload payload = new ResolveDecisionPayload(cluster, namespace, canaryName, revision, stepType);

        return restClient.post()
                .uri("/v1/approvals/resolve")
                .contentType(MediaType.APPLICATION_JSON)
                .body(payload)
                .retrieve()
                .body(HookDecisionResponse.class);
    }

    private record ResolveDecisionPayload(
            String cluster,
            String namespace,
            String canaryName,
            String revision,
            StepType stepType
    ) {
    }
}
