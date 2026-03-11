package com.company.canary.webhook.api;

import com.company.canary.contracts.FlaggerHookRequest;
import com.company.canary.webhook.service.ManualGateDecisionService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/v1/flagger/hooks")
public class ManualGateWebhookController {

    private final ManualGateDecisionService decisionService;

    public ManualGateWebhookController(ManualGateDecisionService decisionService) {
        this.decisionService = decisionService;
    }

    @PostMapping("/manual-gate")
    public ResponseEntity<Map<String, String>> handle(@Valid @RequestBody FlaggerHookRequest request) {
        ManualGateDecisionService.DecisionResult result = decisionService.evaluate(request);
        return ResponseEntity.status(result.status()).body(Map.of("status", result.message()));
    }

    @PostMapping("/manual-rollback")
    public ResponseEntity<Map<String, String>> handleRollback(@Valid @RequestBody FlaggerHookRequest request) {
        FlaggerHookRequest rollbackRequest = new FlaggerHookRequest(
                request.name(),
                request.namespace(),
                "rollback",
                request.checksum(),
                request.metadata()
        );
        ManualGateDecisionService.DecisionResult result = decisionService.evaluate(rollbackRequest);
        return ResponseEntity.status(result.status()).body(Map.of("status", result.message()));
    }
}
