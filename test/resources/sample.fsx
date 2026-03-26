/// Sample F# script for integration testing.

open System

let greeting = "Hello from F# script!"
printfn "%s" greeting

let square x = x * x

let describe x =
    match x with
    | x when x < 0 -> "negative"
    | 0 -> "zero"
    | _ -> "positive"

type Person = { Name: string; Age: int }

let alice = { Name = "Alice"; Age = 30 }
let bob = { Name = "Bob"; Age = 25 }

let work =
    async {
        do! Async.Sleep 100
        return 42
    }

let result = 42
printfn "Result: %d" result
