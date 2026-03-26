/// Sample F# signature file for integration testing.
namespace Sample

/// Compute the area of a shape.
val area : int -> float

/// Compute the factorial of a non-negative integer.
val factorial : int -> int

/// The origin point as a tuple.
val origin : float * float

/// Raised when a shape is invalid.
exception InvalidShape of string

/// Safely get the head of a list.
val safeHead : 'a list -> 'a

/// Classify a number as positive, negative, or zero.
val classify : int -> string

/// Double a number.
val double : int -> int

/// Greet someone by name.
val greet : string -> string

/// Add two numbers.
val add : int -> int -> int
