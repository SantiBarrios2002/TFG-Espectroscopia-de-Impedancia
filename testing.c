#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_SIZE 10

// Structure definition
typedef struct {
    int id;
    char name[50];
    float value;
} Item;

// Function prototypes
void initializeArray(int arr[], int size);
int sumArray(int arr[], int size);
void modifyItem(Item* item, int newId, float newValue);
void printItem(const Item* item);
int factorial(int n);

int main() {
    // Variables for testing
    int numbers[MAX_SIZE];
    int sum = 0;
    int choice = 0;
    Item myItem = {0, "Default", 0.0};
    int n = 0;
    
    printf("Debug Testing Program\n");
    printf("=====================\n\n");
    
    // Initialize array with values
    initializeArray(numbers, MAX_SIZE);
    
    // Calculate and display sum
    sum = sumArray(numbers, MAX_SIZE);
    printf("Sum of array elements: %d\n", sum);
    
    // Working with structures
    printf("\nEnter an ID number: ");
    scanf("%d", &choice);
    
    printf("Enter a value: ");
    float inputValue;
    scanf("%f", &inputValue);
    
    // Modify the structure
    modifyItem(&myItem, choice, inputValue);
    
    // Display the structure
    printf("\nItem after modification:\n");
    printItem(&myItem);
    
    // Calculate factorial
    printf("\nEnter a number to calculate factorial (0-10): ");
    scanf("%d", &n);
    
    if (n >= 0 && n <= 10) {
        int result = factorial(n);
        printf("Factorial of %d is %d\n", n, result);
    } else {
        printf("Please enter a number between 0 and 10\n");
    }
    
    // Demonstrate a loop for stepping through
    printf("\nCounting from 1 to the sum divided by 10:\n");
    for (int i = 1; i <= sum/10; i++) {
        printf("%d ", i);
        if (i % 5 == 0) {
            printf("\n");
        }
    }
    
    printf("\n\nProgram completed successfully!\n");
    return 0;
}

// Initialize array with values 1 through size
void initializeArray(int arr[], int size) {
    for (int i = 0; i < size; i++) {
        arr[i] = i + 1;
    }
}

// Calculate sum of array elements
int sumArray(int arr[], int size) {
    int total = 0;
    for (int i = 0; i < size; i++) {
        total += arr[i];
    }
    return total;
}

// Modify properties of an Item
void modifyItem(Item* item, int newId, float newValue) {
    item->id = newId;
    item->value = newValue;
    
    // Create a name based on the ID
    sprintf(item->name, "Item-%d", newId);
    
    // Add some conditional logic for debugging
    if (newValue > 100) {
        strcat(item->name, "-Premium");
    } else if (newValue > 50) {
        strcat(item->name, "-Standard");
    } else {
        strcat(item->name, "-Basic");
    }
}

// Display item details
void printItem(const Item* item) {
    printf("ID: %d\n", item->id);
    printf("Name: %s\n", item->name);
    printf("Value: %.2f\n", item->value);
}

// Recursive factorial function (good for testing call stack)
int factorial(int n) {
    if (n <= 1) {
        return 1;
    }
    return n * factorial(n - 1);
}