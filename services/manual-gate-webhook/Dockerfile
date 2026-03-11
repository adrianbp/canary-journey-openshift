FROM eclipse-temurin:21-jre
WORKDIR /app
COPY target/manual-gate-webhook-*.jar app.jar
EXPOSE 8082
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
