import Foundation

@main
struct CLOKMain {
    static func main() async {
        let args = CommandLine.arguments.dropFirst()
        
        if args.first?.lowercased() == "setting" {
            let memory = MemoryStore()
            let sub = args.dropFirst().first ?? ""
            if sub.isEmpty {
                Settings.showMenu()
            } else {
                _ = Settings.runSubcommand(sub, memory: memory)
            }
            return
        }
        
        let cli = CLI()
        await cli.run()
    }
}
