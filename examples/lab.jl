file = joinpath(@__DIR__, "elec_pricing.mod")
using AMPLDataReader
model = AMPLDataReader.parse_model(file)

mod = read(file, String)
commands = filter(!isempty, strip.(split(mod, ';')))
for command in commands
    println("-----")
    println(command)
end

for command in commands
    command, rest = AMPLDataReader._get_command(command, ["param", "var", "maximize", "subject to"])
    if command == "subject to"
        break
    end
end
