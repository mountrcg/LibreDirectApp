//
//  AboutView.swift
//  GlucoseDirect
//

import SwiftUI

// MARK: - AboutView

struct AboutView: View {
    // MARK: Internal

    @EnvironmentObject var store: DirectStore

    var body: some View {
        Section(
            content: {
                HStack {
                    Text("App version")
                    Spacer()
                    Text("\(DirectConfig.appVersion) (\(DirectConfig.appBuild))")
                }

                if let appAuthor = DirectConfig.appAuthor, !appAuthor.isEmpty {
                    HStack {
                        Text("App author")
                        Spacer()
                        Text(appAuthor)
                    }
                }

                if let appSupportMail = DirectConfig.appSupportMail, !appSupportMail.isEmpty {
                    HStack {
                        Text("App email")
                        Spacer()
                        Link(appSupportMail, destination: URL(string: "mailto:\(appSupportMail)")!)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                }

                HStack {
                    Text("App website")
                    Spacer()
                    Link("GitHub", destination: URL(string: DirectConfig.githubURL)!)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                HStack {
                    Text("App faq")
                    Spacer()
                    Link("GitHub", destination: URL(string: DirectConfig.faqURL)!)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                HStack {
                    Text("App facebook group")
                    Spacer()
                    Link("Facebook", destination: URL(string: DirectConfig.facebookURL)!)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                HStack {
                    Text("App donate")
                    Spacer()
                    Link("PayPal", destination: URL(string: DirectConfig.donateURL)!)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                HStack {
                    Text("App translation")
                    Spacer()
                    Link("Crowdin", destination: URL(string: DirectConfig.crowdinURL)!)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            },
            header: {
                Label("About \(DirectConfig.appName)", systemImage: "info")
            }
        )

        Button("Send database file", action: {
            store.dispatch(.sendDatabase)
        })

        Button("Send log file", action: {
            store.dispatch(.sendLogs)
        })

        #if DEBUG
        Section(
            content: {
                Button("Debug alarm", action: {
                    store.dispatch(.debugAlarm)
                })

                Button("Debug notification", action: {
                    store.dispatch(.debugNotification)
                })
            },
            header: {
                Label("Debug", systemImage: "testtube.2")
            }
        )
        #endif
    }

    // MARK: Private

    @State private var showingDeleteLogsAlert = false
}
