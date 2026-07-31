# Choose one of the two options below by uncommenting the corresponding section.
# Option 1: Spring Boot executable WAR/JAR runtime (recommended if the WAR is self-contained)
# This does not use the Tomcat base image. It runs the WAR directly with java -jar.

FROM eclipse-temurin:17-jdk AS springboot
WORKDIR /app
COPY *.war /app/app.war
RUN apt-get update && apt-get install -y --no-install-recommends curl unzip && rm -rf /var/lib/apt/lists/*
RUN curl -L -o /tmp/newrelic-java.zip https://download.newrelic.com/newrelic/java-agent/newrelic-agent/current/newrelic-java.zip \
    && unzip -q /tmp/newrelic-java.zip -d /opt \
    && test -f /opt/newrelic/newrelic.jar \
    && rm -f /tmp/newrelic-java.zip
COPY newrelic.yml /opt/newrelic/newrelic.yml
ENTRYPOINT ["java", "-javaagent:/opt/newrelic/newrelic.jar", "-jar", "/app/app.war", "--server.port=8080"]

# Option 2: Deploy WAR to Tomcat (uncomment if you want Tomcat to manage the webapp)
# FROM tomcat:9.0-jdk17-temurin AS tomcat
# RUN rm -rf /usr/local/tomcat/webapps/*
# COPY *.war /usr/local/tomcat/webapps/
# RUN apt-get update && apt-get install -y --no-install-recommends curl unzip && rm -rf /var/lib/apt/lists/*
# RUN curl -L -o /tmp/newrelic-java.zip https://download.newrelic.com/newrelic/java-agent/newrelic-agent/current/newrelic-java.zip \
#     && unzip -q /tmp/newrelic-java.zip -d /opt \
#     && test -f /opt/newrelic/newrelic.jar \
#     && rm -f /tmp/newrelic-java.zip
# COPY newrelic.yml /opt/newrelic/newrelic.yml
# # If Tomcat should start automatically, rely on the base image entrypoint:
# # CMD ["catalina.sh", "run"]
# # If you need a custom JVM startup command, uncomment the line below instead:
# # CMD ["catalina.sh", "run"]