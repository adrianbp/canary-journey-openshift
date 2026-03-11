FROM eclipse-temurin:21-jre
WORKDIR /app
COPY target/approval-api-*.jar app.jar
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
