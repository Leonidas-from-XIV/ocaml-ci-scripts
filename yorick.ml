(*
 * Copyright (c) 2015 David Sheets <sheets@alum.mit.edu>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

(* Brevity is the soul of wit. *)

let env = Hashtbl.create 8
let set = ref ""

let ( *~ ) list sep = String.concat sep list

let apply_env command =
  let set = match !set with
    | "" -> " "
    | opts -> " set "^opts^"; "
  in
  ((Hashtbl.fold (fun k v list -> match v with
     | Some v -> (k^"="^v^" export "^k^";")::list
     | None -> ("unset "^k^";")::list
   ) env []) *~ " ") ^ set ^ command

let (?| ) command = match Sys.command (apply_env command) with
  | 0 -> ()
  | x ->
    Printf.eprintf "'%s' exited %d. Terminating with %d\n" command x x;
    exit x

let (?|.) fmt = Printf.ksprintf (?|) fmt

let (?|~) fmt = Printf.ksprintf (fun command ->
  print_endline command;
  ?|  command
) fmt

let (?|>) fmt = Printf.ksprintf (fun command ->
  let buf = Buffer.create (5*80) in
  let stdout = Unix.open_process_in command in
  try while true do Buffer.add_channel buf stdout 1 done; ""
  with End_of_file -> close_in stdout; Buffer.contents buf
) fmt

let export k v = Hashtbl.replace env k (Some v)

let set opts = set := opts

let unset k = Hashtbl.replace env k None

let map = List.map

let q = Printf.sprintf "\"%s\""

let ql = map q

let split_char_unbounded str ~on =
  let open String in
  if str = "" then []
  else
    let rec loop acc offset =
      try begin
        let index = rindex_from str offset on in
        if index = offset then
          loop (""::acc) (index - 1)
        else
          let token = sub str (index + 1) (offset - index) in
          loop (token::acc) (index - 1)
      end
      with Not_found -> (sub str 0 (offset + 1))::acc
    in loop [] (length str - 1)

let some = function "" -> None | x -> Some x
let list = split_char_unbounded ~on:' '
let lines = split_char_unbounded ~on:'\n'

let getenv_default var default = try Sys.getenv var with Not_found -> default

let (?$) = function
  | "@" -> List.(ql (tl (Array.to_list Sys.argv))) *~ " "
  | v -> match some (getenv_default v "") with
    | Some v -> v
    | None ->
      Printf.eprintf "I don't know what variable '%s' means and I give up.\n" v;
      exit 1

let fuzzy_bool_of_string = function "false" -> false | _ -> true

let echo fmt = Printf.ksprintf print_endline fmt
