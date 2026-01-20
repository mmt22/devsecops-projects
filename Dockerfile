# --- Stage 1: Build the Application ---
FROM maven:3.9.6-eclipse-temurin-17 AS builder
WORKDIR /app

# Copy configuration first (better layer caching)
COPY pom.xml .
# Download dependencies (this layer will be cached unless pom.xml changes)
RUN mvn dependency:go-offline

# Copy source code and build
COPY src ./src
RUN mvn clean package -DskipTests

# --- Stage 2: Create the Secure Runtime Image ---
# We use 'eclipse-temurin:17-jre-alpine' for a tiny, secure footprint
FROM eclipse-temurin:17-jre-alpine

# SECURITY: Create a non-root user. 
# If the container is compromised, the attacker won't be root.
RUN addgroup -S spring && adduser -S spring -G spring

# Create a directory for the app
WORKDIR /app

# Copy only the compiled JAR from the builder stage
COPY --from=builder /app/target/*.jar app.jar

# Switch to non-root user
USER spring:spring

# Expose the port (Standard Spring Boot port)
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
