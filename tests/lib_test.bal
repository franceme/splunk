import ballerina/io;
import ballerina/test;

// Before Suite Function

@test:BeforeSuite
function beforeSuiteFunc() {
    io:println("I'm the before suite function!");
}

// Test function

@test:Config {}
function testFunction() {
    test:assertEquals("Hello, John", "Hello, John");
}

// Negative Test function

@test:Config {}
function negativeTestFunction() {
    test:assertEquals("Hello, World!", "Hello, World!");
}

// After Suite Function

@test:AfterSuite
function afterSuiteFunc() {
    io:println("I'm the after suite function!");
}
