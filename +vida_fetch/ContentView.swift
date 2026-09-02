//
//  ContentView.swift
//  +vida_fetch
//
//  Created by Alvaro Jose Leon Aguilar on 8/26/26.
//
//  Demo: pide permisos de HealthKit y muestra pasos de hoy, ritmo cardíaco
//  (promedio / más bajo / más alto), entrenamientos recientes, exporta el
//  JSON #1 del contrato v2 a un archivo (depuración), y — ticket A7/A9 —
//  lo manda de verdad por POST a /api/v1/sync, con un backfill de los
//  últimos 7 días.
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
                    if let errorPermisos = healthKitManager.errorPermisos {
                        Text(errorPermisos)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    if let errorSincronizacion = healthKitManager.errorSincronizacion {
                        Text(errorSincronizacion)
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
                            // VoiceOver lee esta fila como una sola parada (actividad,
                            // duración, fecha/hora y FC juntos) en vez de 4-5 paradas sueltas.
                            .accessibilityElement(children: .combine)
                        }
                    }
                }

                Section {
                    TextField("usuario_id", text: $healthKitManager.usuarioID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Usuario")
                } footer: {
                    Text("Compartido por todo lo de abajo: exportar a archivo, enviar hoy a Luis y el backfill de 7 días usan este mismo usuario_id.")
                }

                Section {
                    Button {
                        Task { await healthKitManager.exportarJSON() }
                    } label: {
                        if healthKitManager.exportando {
                            ProgressView()
                        } else {
                            Text("Exportar JSON de hoy")
                        }
                    }
                    .disabled(healthKitManager.exportando)

                    if let url = healthKitManager.exportURL {
                        ShareLink(item: url) {
                            Label("Compartir \(url.lastPathComponent)", systemImage: "square.and.arrow.up")
                        }
                    }

                    if let errorExportacion = healthKitManager.errorExportacion {
                        Text(errorExportacion)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Exportar a archivo (depuración)")
                } footer: {
                    Text("Arma el JSON #1 del día de hoy y lo guarda como archivo para inspeccionarlo o compartirlo a mano — no lo manda a ningún lado. Para el envío real, ver las dos secciones de abajo.")
                }

                Section {
                    TextField("http://192.168.1.23:8000", text: $healthKitManager.baseURLTexto)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text("Backend de Luis (dev)")
                } footer: {
                    Text("URL compartida por las dos acciones de abajo. Cambia mientras Luis pasa de correrlo local a un túnel de ngrok a la URL pública de Railway/Render.")
                }

                Section {
                    Button {
                        Task { await healthKitManager.enviarSincronizacion() }
                    } label: {
                        if healthKitManager.enviando {
                            ProgressView()
                        } else {
                            Text("Enviar hoy a Luis")
                        }
                    }
                    .disabled(healthKitManager.enviando || URL(string: healthKitManager.baseURLTexto)?.host == nil)

                    if let respuesta = healthKitManager.respuestaEnvioHoy {
                        VStack(alignment: .leading, spacing: 4) {
                            LabeledContent("Puntos del día", value: "\(respuesta.puntos_dia)")
                            LabeledContent("Puntos del año", value: "\(respuesta.puntos_ano)")
                            LabeledContent("Nivel", value: "\(respuesta.nivel)")
                            if respuesta.tope_diario_aplicado {
                                Text("Tope diario aplicado")
                                    .font(.footnote)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    if let errorEnvio = healthKitManager.errorEnvio {
                        Text(errorEnvio)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Enviar hoy a Luis")
                } footer: {
                    Text("POST /api/v1/sync del día de hoy (A7). El resultado de acá arriba es siempre el de hoy — nunca el del backfill de abajo.")
                }

                Section {
                    Button {
                        Task { await healthKitManager.sincronizarHistorial() }
                    } label: {
                        if healthKitManager.backfillEnProgreso {
                            ProgressView()
                        } else {
                            Text("Traer últimos 7 días")
                        }
                    }
                    .disabled(healthKitManager.backfillEnProgreso || URL(string: healthKitManager.baseURLTexto)?.host == nil)

                    if let ultimoDia = healthKitManager.respuestasHistorial.last {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(healthKitManager.respuestasHistorial.count) de 7 días enviados")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            LabeledContent("Último día — puntos", value: "\(ultimoDia.puntos_dia)")
                            LabeledContent("Último día — nivel", value: "\(ultimoDia.nivel)")
                        }
                    }

                    if let errorBackfill = healthKitManager.errorBackfill {
                        Text(errorBackfill)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Backfill — últimos 7 días")
                } footer: {
                    Text("Trae y manda los últimos 7 días, uno por uno (A9). El resultado de acá arriba es siempre el del backfill — nunca el de \"Enviar hoy a Luis\".")
                }
            }
            .navigationTitle("+Vida — Spike HealthKit")
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        Task {
                            await healthKitManager.solicitarPermisos()
                            if healthKitManager.autorizado {
                                await healthKitManager.sincronizarHistorialSiEsPrimeraVez()
                            }
                        }
                    } label: {
                        if healthKitManager.solicitandoPermisos {
                            ProgressView()
                        } else {
                            Text("Solicitar permisos")
                        }
                    }
                    .disabled(healthKitManager.solicitandoPermisos)
                    Spacer()
                    Button {
                        Task { await healthKitManager.actualizarVistaHoy() }
                    } label: {
                        if healthKitManager.cargando {
                            ProgressView()
                        } else {
                            Text("Actualizar vista")
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
