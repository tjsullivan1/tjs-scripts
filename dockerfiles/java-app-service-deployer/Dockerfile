# ---- build stage ----
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -q -e -DskipTests dependency:go-offline
COPY src ./src
RUN mvn -q -e -DskipTests package

# ---- runtime stage ----
FROM eclipse-temurin:17-jre
WORKDIR /opt/app
COPY --from=build /app/target/azure-webapp-slot-updater-1.0.0-jar-with-dependencies.jar app.jar

# Default command; env vars supply credentials and params.
ENTRYPOINT ["java","-Dorg.slf4j.simpleLogger.log.com.azure.core.http.netty.implementation.NettyUtility=warn","-jar","/opt/app/app.jar"]
