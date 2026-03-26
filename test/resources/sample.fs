/// Sample F# implementation for integration testing.
namespace Sample

open System
open System.Collections.Generic

type Shape =
    | Circle of radius: float
    | Rectangle of width: float * height: float
    | Triangle of base': float * height: float

type Point = { X: float; Y: float }

type Color =
    | Red = 0
    | Green = 1
    | Blue = 2

let area shape =
    match shape with
    | Circle r -> Math.PI * r * r
    | Rectangle(w, h) -> w * h
    | Triangle(b, h) -> 0.5 * b * h

let rec factorial n =
    if n <= 1 then
        1
    else
        n * factorial (n - 1)

let origin : Point = { X = 0.0; Y = 0.0 }

exception InvalidShape of string

// A function using try/with
let safeHead lst =
    try
        List.head lst
    with
    | :? ArgumentException as ex -> raise (InvalidShape ex.Message)
    | _ -> reraise ()

let classify x =
    if x > 0 then
        "positive"
    elif x < 0 then
        "negative"
    else
        "zero"

module MathUtils =
    let square x = x * x
    let cube x = x * x * x

    let clamp lower upper x =
        if x < lower then lower
        elif x > upper then upper
        else x

let sumTo n =
    let mutable total = 0
    for i = 1 to n do
        total <- total + i
    total

let printItems items =
    for item in items do
        printfn "%A" item

let countdown () =
    let mutable n = 10
    while n > 0 do
        printfn "%d" n
        n <- n - 1

let double = fun x -> x * 2

let result = [1; 2; 3] |> List.map (fun x -> x * 2)

let fetchData url =
    async {
        let! response = Async.Sleep 100
        return "data"
    }

let xs = [1; 2; 3]
let ys = [| 4; 5; 6 |]
let pair = (1, "hello")

let greet name = $"Hello, {name}!"

type MyClass(x: int) =
    member this.Value = x
    member this.Add(y: int) = x + y
    static member Create() = MyClass(0)

type IShape =
    abstract member Area : float
    abstract member Name : string

type Circle2(radius: float) =
    interface IShape with
        member _.Area = Math.PI * radius * radius
        member _.Name = "Circle"

let (|Even|Odd|) n =
    if n % 2 = 0 then Even else Odd

let describeNumber n =
    match n with
    | Even -> "even"
    | Odd -> "odd"

[<Obsolete("Use newFunc instead")>]
let oldFunc x = x

let add x y = x + y
let applied = add 1 2

let t = true
let f = false
let u = ()

let intVal = 42
let floatVal = 3.14
let hexVal = 0xFF
let longVal = 42L
