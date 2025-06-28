//MIT License
//
//Copyright © 2025 Cong Le
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.
//
//  ShockAbsorberView.swift
//  Shock_AbsorberApp
//
//  Created by Cong Le on 6/28/25.
//

import SwiftUI

// MARK: - Shock Absorber Simulation View

/// A SwiftUI view that visually simulates and explains the physics of an automotive shock absorber.
///
/// This view demonstrates the principles of damped harmonic motion by modeling a car's suspension system.
/// Users can interact with the simulation by selecting different damping types and observing the effect
/// on both a visual representation of the car and a real-time position-vs-time graph.
///
/// The simulation is driven by a numerical integration of the governing second-order differential equation:
/// `m * a + b * v + k * x = 0`, where 'a' is acceleration, 'v' is velocity, and 'x' is position.
struct ShockAbsorberView: View {
    
    // MARK: - Physics Constants
    
    /// Represents the mass of the car body (in arbitrary units).
    private let mass: CGFloat = 1.0
    
    /// Represents the stiffness of the suspension spring. A higher value means a stiffer spring.
    private let springConstant: CGFloat = 20.0
    
    /// The discrete time step for the physics simulation loop (in seconds).
    /// A smaller value increases accuracy but requires more computation.
    private let timeStep: CGFloat = 0.016 // Approximates a 60 FPS update rate.
    
    // MARK: - Damping Type Definition
    
    /// Defines the different types of damping conditions for the simulation.
    enum DampingType: String, CaseIterable, Identifiable {
        case underdamped = "Underdamped"
        case criticallyDamped = "Critically Damped"
        case overdamped = "Overdamped"
        
        var id: String { self.rawValue }
        
        /// Provides a user-friendly description for each damping type.
        var description: String {
            switch self {
            case .underdamped:
                return "Bouncy: The system oscillates with decreasing amplitude before settling. Common in worn-out shocks."
            case .criticallyDamped:
                return "Ideal: Returns to equilibrium as quickly as possible without oscillation. The goal for automotive shocks."
            case .overdamped:
                return "Slow: Returns to equilibrium very slowly without oscillating. Can feel stiff and unresponsive."
            }
        }
    }
    
    // MARK: - State Variables
    
    /// The core physics engine timer that drives the simulation updates.
    /// It publishes the current time at a rate close to 60 FPS.
    @State private var timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
    
    /// The currently selected damping type for the simulation.
    @State private var selectedDamping = DampingType.criticallyDamped
    
    /// The current damping coefficient (`b` in the physics equation).
    /// This value is derived from the `selectedDamping` type.
    @State private var dampingCoefficient: CGFloat = 0.0
    
    /// The current vertical position (displacement `x`) of the car from its equilibrium point.
    @State private var position: CGFloat = 0.0
    
    /// The current vertical velocity (`v`) of the car.
    @State private var velocity: CGFloat = 0.0
    
    /// Stores a history of the car's position over time to be plotted on the graph.
    @State private var positionHistory: [CGFloat] = []

    // MARK: - Main Body
    
    var body: some View {
        VStack(spacing: 20) {
            // MARK: Title and Description
            VStack {
                Text("🚗 Automotive Shock Absorber")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("A simulation of Damped Harmonic Motion.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            // MARK: Canvas for Visual Simulation
            // This canvas draws the car, wheel, and spring.
            Canvas { context, size in
                drawSimulation(in: context, size: size)
            }
            .frame(height: 150)
            .background(Color(uiColor: .systemGray6))
            .cornerRadius(15)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            )
            
            // MARK: Canvas for Position-Time Graph
            // This canvas plots the car's displacement over time.
            VStack {
                Text("Position vs. Time Graph")
                    .font(.headline)
                Canvas { context, size in
                    drawGraph(in: context, size: size)
                }
                .frame(height: 120)
            }
           
            // MARK: Controls
            VStack(spacing: 15) {
                // Picker for selecting the damping type.
                Picker("Damping Type", selection: $selectedDamping) {
                    ForEach(DampingType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedDamping) { _, _ in
                    hitBump() // Restart simulation when damping type changes.
                }

                // Text description for the selected damping type.
                Text(selectedDamping.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(height: 50)

                // Button to initiate the "bump" and start the simulation.
                Button(action: hitBump) {
                    Label("Hit a Bump!", systemImage: "arrow.up.and.down.circle.fill")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .onAppear(perform: setupInitialState)
        .onReceive(timer) { _ in
            updatePhysics()
        }
    }
    
    // MARK: - Simulation Logic
    
    /// Sets up the initial state of the simulation when the view first appears.
    private func setupInitialState() {
        // Calculate the critical damping coefficient once.
        let criticalDamping = 2 * sqrt(mass * springConstant)
        
        // Assign the appropriate damping coefficient based on the selected type.
        switch selectedDamping {
        case .underdamped:
            dampingCoefficient = criticalDamping * 0.3 // Significantly less than critical
        case .criticallyDamped:
            dampingCoefficient = criticalDamping // Exactly critical
        case .overdamped:
            dampingCoefficient = criticalDamping * 2.0 // Significantly more than critical
        }
    }
    
    /// Resets the simulation state to simulate hitting a bump.
    private func hitBump() {
        // Clear previous history.
        positionHistory.removeAll()
        
        // Set an initial upward displacement to start the oscillation.
        position = -80.0
        
        // Reset velocity to zero at the peak of the bump.
        velocity = 0.0
        
        // Recalculate the damping coefficient based on the current picker selection.
        setupInitialState()
    }

    /// Updates the physics simulation by one time step using Euler integration.
    private func updatePhysics() {
        // 1. Calculate the forces:
        //    - Spring Force: `F_spring = -k * x` (Hooke's Law)
        //    - Damping Force: `F_damping = -b * v` (proportional to velocity)
        let springForce = -springConstant * position
        let dampingForce = -dampingCoefficient * velocity
        
        // 2. Calculate acceleration using Newton's Second Law (F = ma => a = F/m):
        let acceleration = (springForce + dampingForce) / mass
        
        // 3. Update velocity and position (Euler method):
        velocity += acceleration * timeStep
        position += velocity * timeStep
        
        // 4. Store the position for the graph.
        // Cap the history to avoid unbounded memory usage.
        positionHistory.append(position)
        if positionHistory.count > 300 {
            positionHistory.removeFirst()
        }
    }
    
    // MARK: - Drawing Functions
    
    /// Draws the car, wheel, and spring in the top canvas.
    private func drawSimulation(in context: GraphicsContext, size: CGSize) {
        let centerX = size.width / 2
        
        // Define dimensions for the visual elements.
        let carWidth: CGFloat = 120
        let carHeight: CGFloat = 40
        let wheelRadius: CGFloat = 15
        
        // Calculate dynamic positions.
        let groundY = size.height - 20
        let equilibriumY = groundY - wheelRadius * 2 - 50 // The car's resting position
        let carY = equilibriumY + position // Current position affected by physics
        
        // 1. Draw Ground Line
        var groundPath = Path()
        groundPath.move(to: CGPoint(x: 0, y: groundY))
        groundPath.addLine(to: CGPoint(x: size.width, y: groundY))
        context.stroke(groundPath, with: .color(.gray), lineWidth: 2)

        // 2. Draw Wheel
        let wheelRect = CGRect(x: centerX - wheelRadius, y: groundY - wheelRadius * 2, width: wheelRadius * 2, height: wheelRadius * 2)
        context.fill(Path(ellipseIn: wheelRect), with: .color(.black))
        
        // 3. Draw Spring (as a zigzag line)
        var springPath = Path()
        let springTopY = carY + carHeight
        let springBottomY = wheelRect.midY
        let springHeight = springBottomY - springTopY
        springPath.move(to: CGPoint(x: centerX, y: springTopY))
        
        // Create the zigzag effect for the spring.
        let segments = 8
        for i in 1...segments {
            let y = springTopY + CGFloat(i) * (springHeight / CGFloat(segments + 1))
            let xOffset = (i % 2 == 0) ? -10 : 10
            springPath.addLine(to: CGPoint(x: centerX + CGFloat(xOffset), y: y))
        }
        springPath.addLine(to: CGPoint(x: centerX, y: springBottomY))
        context.stroke(springPath, with: .color(.gray), lineWidth: 3)

        // 4. Draw Car Body
        let carRect = CGRect(x: centerX - carWidth / 2, y: carY, width: carWidth, height: carHeight)
        context.fill(Path(roundedRect: carRect, cornerRadius: 5), with: .color(.red))
    }
    
    /// Draws the position vs. time graph in the bottom canvas.
    private func drawGraph(in context: GraphicsContext, size: CGSize) {
        guard !positionHistory.isEmpty else { return }
        
        let path = Path { path in
            let stepX = size.width / CGFloat(max(1, positionHistory.count - 1))
            let midY = size.height / 2
            
            // Move to the starting point of the graph.
            // The position is scaled and offset to fit within the canvas height.
            let firstPosition = midY - (positionHistory[0] / 100.0) * midY
            path.move(to: CGPoint(x: 0, y: firstPosition))
            
            // Add a line for each subsequent data point.
            for index in 1..<positionHistory.count {
                let x = CGFloat(index) * stepX
                let y = midY - (positionHistory[index] / 100.0) * midY
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        // Draw the equilibrium line (y=0).
        var equilibriumPath = Path()
        equilibriumPath.move(to: CGPoint(x: 0, y: size.height / 2))
        equilibriumPath.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        context.stroke(equilibriumPath, with: .color(.gray.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [5]))
        
        // Draw the main oscillation path.
        context.stroke(path, with: .color(.blue), lineWidth: 2)
    }
}

// MARK: - Preview Provider

/// Provides a live preview of the ShockAbsorberView for Xcode's canvas.
struct ShockAbsorberView_Previews: PreviewProvider {
    static var previews: some View {
        ShockAbsorberView()
    }
}
