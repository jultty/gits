open Unix ;;
open Sys ;;

(* constants *)
let rebase_status = "## rebasing...rebasing"

(* io/system *)
let print s = print_endline s
let i x = ignore x
let run c = ignore(command c)
let get c = input_line (open_process_in c)

let diss c =
  let proc_exit = command (c ^ " 2> /dev/null 1> /dev/null") in
  if proc_exit = 0 then true else false

let read_string ch = let res = Buffer.create 1024 in
  let rec read () =
    match input_line ch with
    | line ->
        Buffer.add_string res line ;
        Buffer.add_string res "\n" ;
        read ()
    | exception End_of_file -> Buffer.contents res
  in
  read ()

let get_dir p = if !p <> "" then !p else getcwd ()

let get_status d = begin
  let ic = open_process_args_in "git"
    [|"git"; "-C"; d; "status"; "--porcelain=1"; "--branch"; |] in
  let list = String.split_on_char '\n' (read_string ic) in
  let list = List.filter (fun e -> String.trim e <> "" && e <> "\n") list in
  list
end

let is_repo d = if diss ("git -C " ^ d ^ " status") then true else false
let get_plumbing_branch d = get ("git -C " ^ d ^ " symbolic-ref --short HEAD")

(* files *)
let string_of_char c = String.make 1 c

let clear ="\x1b[0m"
let color s = "\x1b[38;5;" ^ string_of_int s ^ "m"
let green s =  color 107 ^ s ^ clear
let teal s = color 36 ^ s ^ clear
let purple s = color 171 ^ s ^ clear
let blue s = color 31 ^ s ^ clear
let cyan s = color 50 ^ s ^ clear
let yellow s = color 3 ^ s ^ clear
let red s = color 167 ^ s ^ clear
let orange s = color 172 ^ s ^ clear

let color_by_status_symbol c = begin
  match c with
  | 'D' -> red(string_of_char c)
  | '?' -> orange(string_of_char c)
  | 'M' -> yellow(string_of_char c)
  | 'U' -> yellow(string_of_char c)
  | 'I' -> blue(string_of_char c)
  | 'C' -> blue(string_of_char c)
  | 'R' -> cyan(string_of_char c)
  | 'A' -> green(string_of_char c)
  | _ -> string_of_char c
end

let color_status arr i = begin
  if Array.length arr >= i && arr.(i) <> "" then begin
    let original_str = arr.(i) in
    if arr.(i) = "??" then begin
      arr.(i) <- orange arr.(i) (* ^ " " ^ arr.(i + 1) *) ;
    end else begin
    if i = 0 then
      arr.(i) <- teal (string_of_char (String.get original_str i)) ;
    if i = 0 && arr.(i + 1) <> "" then
      arr.(i) <- arr.(i) ^
        color_by_status_symbol (String.get original_str (i + 1))
    else if i = 1 then
      if String.length original_str == 1 then
        arr.(i) <- color_by_status_symbol (String.get original_str 0)
      else if i = 2 then
        arr.(i) <- arr.(i)
    end
  end ;
  (* "<" ^ arr.(i) ^ ">" *)
  arr.(i)
end

let assemble_status i arr = begin
  arr.(0) <- color_status arr 0 ;
  arr.(1) <- color_status arr 1 ;
  if Array.length arr > 2 then
  arr.(2) <- color_status arr 2 ;
  arr
end

(* branch *)
let rec find_ellipsis s i =
  if String.get s i = '.' &&
  String.get s (i + 1) = '.' &&
  String.get s (i + 2) = '.' then
    i else find_ellipsis s (i + 1)

let get_branch_status s remote_end = begin
  let status_index = String.index_from_opt s (remote_end + 1) '[' in
  match status_index with
  | Some v -> String.sub s (v + 1) (String.length s - v - 2)
  | None -> ""
end

let handle_empty s d = begin
  if s <> rebase_status then begin
    let branch = get_plumbing_branch d in
    if String.trim s = "## main" then "## " ^ branch ^ "...untracked"
    else if (String.sub s 0 20) = "## No commits yet on" then "## " ^ branch ^ "...uncommitted"
    else s
  end else s
end

let handle_rebase s d = begin
  if String.trim s = "## HEAD (no branch)" then rebase_status
  else s
end

let assemble_branch_status s = begin
  let ellipsis_index = find_ellipsis s 0 in
  let branch = String.sub s 3 (ellipsis_index - 3) in

  let remote_end_opt = String.index_from_opt s (ellipsis_index + 3) ' ' in
  let remote_end =
    match remote_end_opt with
    | Some v -> v
    | None -> (String.length s - 1) in
  let status_length = (String.length s) - remote_end in
  let remote_length =
    match remote_end_opt with
    | Some v -> ((String.length s) - status_length - (String.length branch) - 6)
    | None -> String.length s - (ellipsis_index + 3) in
  let remote = String.sub s (ellipsis_index + 3) remote_length in
  let status = get_branch_status s remote_end in
  branch ^ " " ^ remote ^ " " ^ status
end

let insert_branch_icon i s = begin
  match i with
  (* ⎇   main     origin/main    ahead 2 *)
  | 0 -> green " ⎇ " ^ "  " ^ teal s
  | 1 -> "    " ^ s
  | 2 -> cyan "   " ^ s
  | _ -> s
end

let add_branch_icons s = begin
  let list = String.split_on_char ' ' s in
  let list = List.map String.trim list in
  let list = List.filter (fun e -> e <> "") list in
  let arr = Array.of_list list in
  let arr = Array.mapi insert_branch_icon arr in
  let list = Array.to_list arr in
  list
end

(* io *)
let get_files d = begin
  let list = get_status d in
  let arr = Array.of_list list in
  let arr = Array.map (fun s -> Array.of_list (String.split_on_char ' ' s)) arr in
  let arr = Array.mapi (fun e -> assemble_status e) arr in
  let arr = Array.map (fun l -> String.concat " " (Array.to_list l)) arr in
  let list = Array.to_list arr in
  let list = List.map (fun e -> " " ^ e) list in
  List.tl list
end

let print_files d = begin
  let files = get_files d in
  if List.length files > 0 then begin
    i(List.map print files) ;
    run "echo" ;
  end
end

let get_branch d = begin
  let status = get_status d in
  let branch_line = List.hd status in
  let branch_line = handle_rebase branch_line d in
  let branch_line = handle_empty branch_line d in
  let branch_line = assemble_branch_status branch_line in
  let branch_line = add_branch_icons branch_line in
  String.concat " " branch_line
end

(* arg parsing *)
let usage_msg = "gits [-p <path>]"
let path = ref ""
let others = ref []
let anon_fun other = others := other::!others
let speclist = [
  ("-p", Arg.Set_string path, "Git repository path")
  ] ;;

Arg.parse speclist anon_fun usage_msg

(* entry point *)
let main = begin
  let dir = (get_dir path) in
  if is_repo dir then begin
    run "echo" ;
    print_files dir ;
    print (get_branch dir) ;
    run "echo" ;
  end
  else begin
    print ("Not a git repo: " ^ dir) ;
    exit 1
  end ;
end ;;

main
