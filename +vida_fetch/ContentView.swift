//
//  ContentView.swift
//  +vida_fetch
//
//  Created by Alvaro Jose Leon Aguilar on 8/26/26.
//
//  Demo: pide permisos de HealthKit y muestra pasos de hoy, ritmo cardíaco
//  (promedio / más bajo / más alto), entrenamientos recientes, exporta el
//  JSON #1 del contrato v3 a un archivo (depuración), y — ticket A7/A9 —
//  lo manda de verdad por POST a /api/v1/sync, con un backfill de los
//  últimos 7 días.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @Environment(\.scenePhase) private var scenePhase

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
                    Text("Calculado local, sin deduplicar — puede estar inflado si hay más de una fuente activa. El número real es \"pasos_totales_dia\" en la respuesta de Luis, abajo.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                    .disabled(healthKitManager.ocupado || !healthKitManager.urlBackendValida)

                    if let respuesta = healthKitManager.respuestaEnvioHoy {
                        VStack(alignment: .leading, spacing: 4) {
                            if let cuando = healthKitManager.respuestaEnvioHoyEn {
                                // Relativo y no la hora sola: si la app pasó
                                // un día en segundo plano, "1:33 PM" puede ser
                                // de anteayer y se lee como si fuera de recién.
                                Text("Recibido \(cuando.formatted(.relative(presentation: .named)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            LabeledContent("Pasos del día (dedup)", value: "\(respuesta.pasos_totales_dia)")
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

                // Sección propia y no dentro de "Enviar hoy": la cola la
                // alimentan las dos acciones (el envío de hoy y el backfill),
                // así que el control para vaciarla no puede vivir dentro de
                // una sola de ellas. Antes el backfill avisaba "quedaron 3
                // días encolados" en su sección y el botón para resolverlo
                // estaba en otra, más arriba.
                if healthKitManager.pendientesEnCola > 0 || healthKitManager.errorReintento != nil {
                    Section {
                        if healthKitManager.pendientesEnCola > 0 {
                            HStack {
                                Image(systemName: "tray.and.arrow.up")
                                    .foregroundStyle(.orange)
                                Text("^[\(healthKitManager.pendientesEnCola) día](inflect: true) sin enviar")
                                    .foregroundStyle(.orange)
                                    .contentTransition(.numericText())

                                Spacer()

                                Button {
                                    Task { await healthKitManager.reintentarPendientes() }
                                } label: {
                                    if healthKitManager.reintentando {
                                        ProgressView()
                                    } else {
                                        Text("Reintentar")
                                    }
                                }
                                // Ancho fijo: sin esto la fila se recorre al
                                // tocar, porque el spinner y el texto miden
                                // distinto.
                                .frame(minWidth: 72, alignment: .trailing)
                                .disabled(healthKitManager.ocupado || !healthKitManager.urlBackendValida)
                            }
                            .font(.footnote)
                            .transition(.opacity)
                        }

                        if let errorReintento = healthKitManager.errorReintento {
                            Text(errorReintento)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    } header: {
                        Text("Cola de reintentos")
                    } footer: {
                        Text("Días que no se pudieron enviar (A8). Se reintentan solos al abrir la app y al volver del segundo plano; los datos se releen de HealthKit en cada intento, así que un día que siguió sumando pasos después del fallo se manda completo.")
                    }
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
                    .disabled(healthKitManager.ocupado || !healthKitManager.urlBackendValida)

                    if let ultimoDia = healthKitManager.respuestasHistorial.last {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(healthKitManager.respuestasHistorial.count) de 7 días enviados")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            LabeledContent("Último día — pasos (dedup)", value: "\(ultimoDia.pasos_totales_dia)")
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
            .animation(.spring(duration: 0.3, bounce: 0), value: healthKitManager.pendientesEnCola)
            // La cola se drena sola en los dos momentos en que realmente
            // puede haber vuelto la red: al abrir la app y al traerla de
            // vuelta del background. Antes solo se intentaba desde el botón
            // "Solicitar permisos", que el usuario toca una vez y nunca más.
            // Si la cola está vacía, `reintentarPendientes()` sale de
            // inmediato sin tocar la red.
            .task {
                await healthKitManager.reintentarPendientes()
            }
            .onChange(of: scenePhase) { _, fase in
                guard fase == .active else { return }
                Task { await healthKitManager.reintentarPendientes() }
            }
            .navigationTitle("+Vida — Spike HealthKit")
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        Task {
                            await healthKitManager.solicitarPermisos()
                            if healthKitManager.autorizado {
                                await healthKitManager.sincronizarHistorialSiEsPrimeraVez()
                                // A8: si quedó algo pendiente de una sesión
                                // anterior sin red, aprovechamos que se abrió
                                // la app para intentar vaciar la cola.
                                await healthKitManager.reintentarPendientes()
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
