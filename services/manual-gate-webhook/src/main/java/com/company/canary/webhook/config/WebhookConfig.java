package com.company.canary.webhook.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;

@Configuration
@EnableConfigurationProperties(ApprovalApiProperties.class)
public class WebhookConfig {

    @Bean
    public RestClient approvalApiRestClient(ApprovalApiProperties properties) {
        return RestClient.builder().baseUrl(properties.getBaseUrl()).build();
    }
}
