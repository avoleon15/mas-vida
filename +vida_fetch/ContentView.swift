//
//  ContentView.swift
//  +vida_fetch
//
//  Created by Alvaro Jose Leon Aguilar on 8/26/26.
//
//  Demo: pide permisos de HealthKit y muestra pasos de hoy, ritmo cardíaco
//  (promedio / más bajo / más alto) y entrenamientos recientes.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager()

    var body: some View {
        NavigationStack {
            List {
                Section("Estado") {
                    LabeledContent("Permisos") {
                        Text(healthKitManager.autorizado ? "Concedidos" : "No solicitados")
                            .foregroundStyle(healthKitManager.autorizado ? .green : .secondary)
                    }
                    if let ultima = healthKitManager.ultimaSincronizacion {
                        LabeledContent("Última sincronización") {
                            Text(ultima, style: .time)
                        }
                    }
                    if let error = healthKitManager.error {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("Pasos de hoy") {
                    Text("\(Int(healthKitManager.pasosHoy)) pasos")
                        .font(.title2.bold())
                }

                Section("Ritmo cardíaco (hoy)") {
                    LabeledContent("Promedio", value: formateaFC(healthKitManager.frecuenciaCardiacaHoy.promedio))
                    LabeledContent("Más bajo", value: formateaFC(healthKitManager.frecuenciaCardiacaHoy.minimo))
                    LabeledContent("Más alto", value: formateaFC(healthKitManager.frecuenciaCardiacaHoy.maximo))
                }

                Section("Entrenamientos (últimos 7 días)") {
                    if healthKitManager.entrenamientos.isEmpty {
                        Text("Sin entrenamientos registrados")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(healthKitManager.entrenamientos) { workout in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(workout.tipoActividad)
                                        .bold()
                                    Spacer()
                                    Text("\(Int(workout.duracionMinutos)) min")
                                        .foregroundStyle(.secondary)
                                }
                                HStack {
                                    Text(workout.inicio, style: .date)
                                    Text(workout.inicio, style: .time)
                                }
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                if let fc = workout.promedioFC {
                                    Text("FC promedio: \(Int(fc.rounded())) bpm")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("+Vida — Spike HealthKit")
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Solicitar permisos") {
                        Task { await healthKitManager.solicitarPermisos() }
                    }
                    Spacer()
                    Button {
                        Task { await healthKitManager.sincronizar() }
                    } label: {
                        if healthKitManager.cargando {
                            ProgressView()
                        } else {
                            Text("Sincronizar")
                        }
                    }
                    .disabled(healthKitManager.cargando)
                }
            }
        }
    }

    private func formateaFC(_ valor: Double?) -> String {
        guard let valor else { return "—" }
        return "\(Int(valor.rounded())) bpm"
    }
}

#Preview {
    ContentView()
}
