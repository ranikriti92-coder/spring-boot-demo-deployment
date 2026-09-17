package com.example.demo.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {

    // This value comes from application.yml / application-<profile>.yml
    // It lets us prove, just by hitting the URL, which environment we are in.
    @Value("${app.environment:local}")
    private String environment;

    @GetMapping("/")
    public String home() {
        return "Hello World! This Spring Boot app is running in the '" + environment + "' environment.";
    }

    @GetMapping("/api/version")
    public String version() {
        return "demo-app....v1 - environment=" + environment;
    }
}
