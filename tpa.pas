unit tpa;
{==============================================================================]
  Copyright:
   - Copyright (c) 2016, Jarl `slacky` Holta
   - Raymond van Venetië and Merlijn Wajer
  License: GNU General Public License (https://www.gnu.org/licenses/gpl-3.0)
  Links:
   - https://github.com/Torwent/Simba/blob/simba1400/Source/MML/simba.tpa.pas
   - https://github.com/Villavu/Simba/blob/simba2000/Source/simba.vartype_pointarray.pas
[==============================================================================}
{$mode objfpc}{$H+}

interface

uses sysutils, types;

function NRSplitTPA(const arr: TPointArray; dist: Double): T2DPointArray;
function NRClusterTPA(const tpa: TPointArray; dist: Double): T2DPointArray;
function SkeletonTPA(tpa: TPointArray; fMin, fMax: Int32): TPointArray;
function TPAMatrix(tpa: TPointArray): T2DBoolArray;

type TNode = record Pt: TPoint; Weight: Int32; end;
type TQueue = array of TNode;

procedure _SiftDown(var queue: TQueue; startpos, pos: Int32);
procedure _SiftUp(var queue: TQueue; pos: Int32);

type TAStarNodeData = record Parent: TPoint; Open, Closed: Boolean; ScoreA, ScoreB: Int32; end;
type TAStarData = array of array of TAStarNodeData;

procedure _Push(var queue: TQueue; node: TNode; var data: TAStarData; var size: Int32);
function _Pop(var queue: TQueue; var data: TAStarData; var size: Int32): TNode;
function _BuildPath(start, goal: TPoint; data: TAStarData; offset: TPoint): TPointArray;

function AStarTPAEx(tpa: TPointArray; out paths: T2DFloatArray; start, goal: TPoint; diagonalTravel: Boolean): TPointArray;

function AStarTPA(tpa: TPointArray; start, goal: TPoint; diagonalTravel: Boolean): TPointArray; overload;

implementation

uses Math;


function NRSplitTPA(const arr: TPointArray; dist: Double): T2DPointArray;
var
  t1, t2, c, ec, tc, l: Integer;
  tpa: TPointArray;
begin
  tpa := Copy(arr);
  l := High(tpa);
  if (l < 0) then Exit;
  SetLength(Result, l + 1);
  c := 0;
  ec := 0;
  while ((l - ec) >= 0) do
  begin
    SetLength(Result[c], 1);
    Result[c][0] := tpa[0];
    tpa[0] := tpa[l - ec];
    Inc(ec);
    tc := 1;
    t1 := 0;
    while (t1 < tc) do
    begin
      t2 := 0;
      while (t2 <= (l - ec)) do
      begin
        if (sqrt(Sqr(Result[c][t1].x - tpa[t2].x) + Sqr(Result[c][t1].y - tpa[t2].y)) <= dist) then
        begin
          SetLength(Result[c], tc +1);
          Result[c][tc] := tpa[t2];
          tpa[t2] := tpa[l - ec];
          Inc(ec);
          Inc(tc);
          Dec(t2);
        end;
        Inc(t2);
      end;
      Inc(t1);
    end;
    Inc(c);
  end;
  SetLength(Result, c);
end;

function NRClusterTPA(const tpa: TPointArray; dist: Double): T2DPointArray;
type
  TPointScan = record
    skipRow: Boolean;
    count: Integer;
  end;
var
  h, i, l, c, s, x, y, o, r, d, m: Integer;
  p: array of array of TPointScan;
  q: TPointArray;
  a, b, t: TBox;
  e: Extended;
  z: TPoint;
  v: Boolean;
begin
  SetLength(Result, 0);
  h := High(TPA);
  if (h > -1) then
    if (h > 0) then
    begin
      b.X1 := TPA[0].X;
      b.Y1 := TPA[0].Y;
      b.X2 := TPA[0].X;
      b.Y2 := TPA[0].Y;
      r := 0;
      for i := 1 to h do
      begin
        if (TPA[i].X < b.X1) then
          b.X1 := TPA[i].X
        else
          if (TPA[i].X > b.X2) then
            b.X2 := TPA[i].X;
        if (TPA[i].Y < b.Y1) then
          b.Y1 := TPA[i].Y
        else
          if (TPA[i].Y > b.Y2) then
            b.Y2 := TPA[i].Y;
      end;
      SetLength(p, ((b.X2 - b.X1) + 1));
      for i := 0 to (b.X2 - b.X1) do
      begin
        SetLength(p[i], ((b.Y2 - b.Y1) + 1));
        for c := 0 to (b.Y2 - b.Y1) do
        begin
          p[i][c].count := 0;
          p[i][c].skipRow := False;
        end;
      end;
      e := dist;
      if (e < 0.0) then
        e := 0.0;
      d := Ceil(e);
      m := Max(((b.X2 - b.X1) + 1), ((b.Y2 - b.Y1) + 1));
      if (d > m) then
        d := m;
      for i := 0 to h do
        Inc(p[(TPA[i].X - b.X1)][(TPA[i].Y - b.Y1)].count);
      for i := 0 to h do
        if (p[(TPA[i].X - b.X1)][(TPA[i].Y - b.Y1)].count > 0) then
        begin
          c := Length(Result);
          SetLength(Result, (c + 1));
          SetLength(Result[c], p[(TPA[i].X - b.X1)][(TPA[i].Y - b.Y1)].count);
          for o := 0 to (p[(TPA[i].X - b.X1)][(TPA[i].Y - b.Y1)].count - 1) do
            Result[c][o] := TPA[i];
          r := (r + p[(TPA[i].X - b.X1)][(TPA[i].Y - b.Y1)].count);
          if (r > h) then
            Exit;
          SetLength(q, 1);
          q[0] := TPA[i];
          p[(TPA[i].X - b.X1)][(TPA[i].Y - b.Y1)].count := 0;
          s := 1;
          while (s > 0) do
          begin
            s := High(q);
            z := q[s];
            a.X1 := (z.X - d);
            a.Y1 := (z.Y - d);
            a.X2 := (z.X + d);
            a.Y2 := (z.Y + d);
            t := a;
            SetLength(q, s);
            if (a.X1 < b.X1) then
              a.X1 := b.X1
            else
              if (a.X1 > b.X2) then
                a.X1 := b.X2;
            if (a.Y1 < b.Y1) then
              a.Y1 := b.Y1
            else
              if (a.Y1 > b.Y2) then
                a.Y1 := b.Y2;
            if (a.X2 < b.X1) then
              a.X2 := b.X1
            else
              if (a.X2 > b.X2) then
                a.X2 := b.X2;
            if (a.Y2 < b.Y1) then
              a.Y2 := b.Y1
            else
              if (a.Y2 > b.Y2) then
                a.Y2 := b.Y2;
            case ((t.X1 <> a.X1) or (t.X2 <> a.X2)) of
              True:
              for y := a.Y1 to a.Y2 do
                if not p[(a.X2 - b.X1)][(y - b.Y1)].skipRow then
                for x := a.X1 to a.X2 do
                  if (p[(x - b.X1)][(y - b.Y1)].count > 0) then
                    if (Sqrt(Sqr(z.X - x) + Sqr(z.Y - y)) <= dist) then
                    begin
                      l := Length(Result[c]);
                      SetLength(Result[c], (l + p[(x - b.X1)][(y - b.Y1)].count));
                      for o := 0 to (p[(x - b.X1)][(y - b.Y1)].count - 1) do
                      begin
                        Result[c][(l + o)].X := x;
                        Result[c][(l + o)].Y := y;
                      end;
                      r := (r + p[(x - b.X1)][(y - b.Y1)].count);
                      if (r > h) then
                        Exit;
                      p[(x - b.X1)][(y - b.Y1)].count := 0;
                      SetLength(q, (s + 1));
                      q[s] := Result[c][l];
                      Inc(s);
                    end;
              False:
              for y := a.Y1 to a.Y2 do
                if not p[(a.X2 - b.X1)][(y - b.Y1)].skipRow then
                begin
                  v := True;
                  for x := a.X1 to a.X2 do
                    if (p[(x - b.X1)][(y - b.Y1)].count > 0) then
                      if (Sqrt(Sqr(z.X - x) + Sqr(z.Y - y)) <= dist) then
                      begin
                        l := Length(Result[c]);
                        SetLength(Result[c], (l + p[(x - b.X1)][(y - b.Y1)].count));
                        for o := 0 to (p[(x - b.X1)][(y - b.Y1)].count - 1) do
                        begin
                          Result[c][(l + o)].X := x;
                          Result[c][(l + o)].Y := y;
                        end;
                        r := (r + p[(x - b.X1)][(y - b.Y1)].count);
                        if (r > h) then
                          Exit;
                        p[(x - b.X1)][(y - b.Y1)].count := 0;
                        SetLength(q, (s + 1));
                        q[s] := Result[c][l];
                        Inc(s);
                      end else
                        v := False;
                  if v then
                    p[(a.X2 - b.X1)][(y - b.Y1)].skipRow := True;
                end;
            end;
          end;
        end;
    end else
    begin
      SetLength(Result, 1);
      SetLength(Result[0], 1);
      Result[0][0] := TPA[0];
    end;
end;

function SkeletonTPA(tpa: TPointArray; fMin, fMax: Int32): TPointArray;
  function _TransitCount(const p2,p3,p4,p5,p6,p7,p8,p9: Int32): Int32;
  begin
    Result := 0;

    if ((p2 = 0) and (p3 = 1)) then Inc(Result);
    if ((p3 = 0) and (p4 = 1)) then Inc(Result);
    if ((p4 = 0) and (p5 = 1)) then Inc(Result);
    if ((p5 = 0) and (p6 = 1)) then Inc(Result);
    if ((p6 = 0) and (p7 = 1)) then Inc(Result);
    if ((p7 = 0) and (p8 = 1)) then Inc(Result);
    if ((p8 = 0) and (p9 = 1)) then Inc(Result);
    if ((p9 = 0) and (p2 = 1)) then Inc(Result);
  end;

var
  j,i,x,y,h,transit,sumn,MarkHigh,hits: Int32;
  p2,p3,p4,p5,p6,p7,p8,p9:Int32;
  Change, PTS: TPointArray;
  Matrix: array of TBoolArray;
  iter: Boolean;
  B: TBox;
begin
  h := High(tpa);
  if (h <= 0) then
    Exit;

  B := GetTPABounds(tpa);
  B.X1 -= 2;
  B.Y1 -= 2;

  SetLength(Matrix, (B.Y2 - B.Y1 + 1) + 2, (B.X2 - B.X1 + 1) + 2);
  SetLength(PTS, h + 1);

  for i := 0 to h do
  begin
    x := tpa[i].X - B.X1;
    y := tpa[i].Y - B.Y1;
    PTS[i] := Point(x, y);
    Matrix[y, x] := True;
  end;

  j := 0;
  MarkHigh := h;
  SetLength(Change, h+1);

  repeat
    iter := (j mod 2) = 0;
    Hits := 0;
    i := 0;
    while (i < MarkHigh) do
    begin
      x := PTS[i].x;
      y := PTS[i].y;
      p2 := Ord(Matrix[y-1,x]);
      p4 := Ord(Matrix[y,x+1]);
      p6 := Ord(Matrix[y+1,x]);
      p8 := Ord(Matrix[y,x-1]);

      if iter then
      begin
        if (((p4 * p6 * p8) <> 0) or ((p2 * p4 * p6) <> 0)) then
        begin
          Inc(i);
          Continue;
        end;
      end
      else if ((p2 * p4 * p8) <> 0) or ((p2 * p6 * p8) <> 0) then
      begin
        Inc(i);
        Continue;
      end;

      p3 := Ord(Matrix[y-1,x+1]);
      p5 := Ord(Matrix[y+1,x+1]);
      p7 := Ord(Matrix[y+1,x-1]);
      p9 := Ord(Matrix[y-1,x-1]);
      Sumn := (p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9);
      if (SumN >= FMin) and (SumN <= FMax) then
      begin
        Transit := _TransitCount(p2,p3,p4,p5,p6,p7,p8,p9);
        if (Transit = 1) then
        begin
          Change[Hits] := PTS[i];
          Inc(Hits);
          PTS[i] := PTS[MarkHigh];
          PTS[MarkHigh] := Point(x, y);
          Dec(MarkHigh);
          Continue;
        end;
      end;
      Inc(i);
    end;

    for i:=0 to (Hits-1) do
      Matrix[Change[i].y, Change[i].x] := False;

    inc(j);
  until ((Hits=0) and (Iter=False));

  SetLength(Result, (MarkHigh + 1));
  for i := 0 to MarkHigh do
    Result[i] := Point(PTS[i].X+B.X1, PTS[i].Y+B.Y1);
end;

function TPAMatrix(tpa: TPointArray): T2DBoolArray;
var
  b: TBox;
  p: TPoint;
begin
  b := GetTPABounds(tpa);
  SetLength(Result, b.Y2+1, b.X2+1);
  for p in tpa do Result[p.Y, p.X] := True;
end;


//AStar
procedure _SiftDown(var queue: TQueue; startpos, pos: Int32);
var
  parentpos: Int32;
  parent,newitem: TNode;
begin
  newitem := queue[pos];
  while pos > startpos do
  begin
    parentpos := (pos - 1) shr 1;
    parent := queue[parentpos];
    if (newitem.Weight < parent.Weight) then
    begin
      queue[pos] := parent;
      pos := parentpos;
      continue;
    end;
    Break;
  end;
  queue[pos] := newitem;
end;

procedure _SiftUp(var queue: TQueue; pos: Int32);
var
  endpos, startpos, childpos, rightpos: Int32;
  newitem: TNode;
begin
  endpos := Length(queue);
  startpos := pos;
  newitem := queue[pos];
  // Move the smaller child up until hitting a leaf.
  childpos := 2 * pos + 1;    // leftmost child
  while (childpos < endpos) do
  begin
    // Set childpos to index of smaller child.
    rightpos := childpos + 1;
    if (rightpos < endpos) and (queue[childpos].Weight >= queue[rightpos].Weight) then
      childpos := rightpos;
    // Move the smaller child up.
    queue[pos] := queue[childpos];
    pos := childpos;
    childpos := 2 * pos + 1;
  end;
  // This (`pos`) node/leaf is empty. So we can place "newitem" in here, then
  // push it up to its final place (by sifting its parents down).
  queue[pos] := newitem;
  _SiftDown(queue, startpos, pos);
end;

procedure _Push(var queue: TQueue; node: TNode; var data: TAStarData; var size: Int32);
var
  i: Int32;
begin
  i := Length(queue);
  SetLength(queue, i + 1);
  queue[i] := node;
  _SiftDown(queue, 0, i);
  data[node.Pt.Y, node.Pt.X].Open := True;
  Inc(size);
end;

function _Pop(var queue: TQueue; var data: TAStarData; var size: Int32): TNode;
var
  node: TNode;
begin
  node := queue[High(queue)];
  SetLength(queue, High(queue));

  if Length(queue) > 0 then
  begin
    Result := queue[0];
    queue[0] := node;
    _SiftUp(queue, 0);
  end
  else
    Result := node;

  data[Result.Pt.Y, Result.Pt.X].Open := False;
  data[Result.Pt.Y, Result.Pt.X].Closed := True;
  Dec(size);
end;

function _BuildPath(start, goal: TPoint; data: TAStarData; offset: TPoint): TPointArray;
var
  tmp: TPoint;
  len: Int32 = 0;
begin
  tmp := goal;

  while tmp <> start do
  begin
    Inc(len);
    SetLength(Result, len);
    Result[len-1].X := tmp.X + offset.X;
    Result[len-1].Y := tmp.Y + offset.Y;
    tmp := data[tmp.Y, tmp.X].Parent;
  end;

  Inc(len);
  SetLength(Result, len);
  Result[len-1].X := tmp.X + offset.X;
  Result[len-1].Y := tmp.Y + offset.Y;
  TPAReverse(Result);
end;


function AStarTPAEx(tpa: TPointArray; out paths: T2DFloatArray; start, goal: TPoint; diagonalTravel: Boolean): TPointArray;
const
  OFFSETS: array[0..7] of TPoint = ((X:0; Y:-1),(X:-1; Y:0),(X:1; Y:0),(X:0; Y:1),(X:1; Y:-1),(X:-1; Y:1),(X:1; Y:1),(X:-1; Y:-1));
var
  b: TBox;
  queue: TQueue;
  data: TAStarData;
  matrix: T2DBoolArray;
  score, i, hi, size: Int32;
  node: TNode;
  tl, q, p: TPoint;
begin
  b := GetTPABounds(tpa);
  if not b.Contains(start) then Exit;
  if not b.Contains(goal) then Exit;

  tl.X := b.X1;
  tl.Y := b.Y1;
  start.X -= tl.X;
  start.Y -= tl.Y;
  goal.X -= tl.X;
  goal.Y -= tl.Y;

  b.X1 := 0;
  b.Y1 := 0;
  b.X2 -= tl.X;
  b.Y2 -= tl.Y;

  SetLength(matrix, b.Y2+1, b.X2+1);

  for i := 0 to High(tpa) do
  begin
    tpa[i].X -= tl.X;
    tpa[i].Y -= tl.Y;
    matrix[tpa[i].Y, tpa[i].X] := True;
  end;

  if not matrix[start.Y, start.X] then Exit;
  if not matrix[goal.Y, goal.X] then Exit;

  paths := [];
  SetLength(paths, b.Y2+1, b.X2+1);
  SetLength(data, b.Y2+1, b.X2+1);

  data[start.Y, start.X].ScoreB := Sqr(start.X - goal.X) + Sqr(start.Y - goal.Y);

  node.Pt := start;
  node.Weight := data[start.Y, start.X].ScoreB;
  _Push(queue, node, data, size);

  if diagonalTravel then hi := 7 else hi := 3;

  while (size > 0) do
  begin
    node := _Pop(queue, data, size);
    p := node.Pt;

    if p = goal then Exit(_BuildPath(start, goal, data, tl));

    for i := 0 to hi do
    begin
      q := p + OFFSETS[i];

      if not b.Contains(q) then Continue;
      if not matrix[q.Y, q.X] then Continue;

      score := data[p.Y, p.X].ScoreA + 1;

      if data[q.Y, q.X].Closed and (score >= data[q.Y, q.X].ScoreA) then
        Continue;
      if data[q.Y, q.X].Open and (score >= data[q.Y, q.X].ScoreA) then
        Continue;

      data[q.Y, q.X].Parent := p;
      data[q.Y, q.X].ScoreA := score;
      data[q.Y, q.X].ScoreB := data[q.Y, q.X].ScoreA + Sqr(q.X - goal.X) + Sqr(q.Y - goal.Y);;

      if data[q.Y, q.X].Open then Continue;

      paths[q.Y, q.X] := score;
      //DEBUG_IMG.DrawMatrix(paths);
      //DEBUG_IMG.Debug();

      node.Pt := q;
      node.Weight := data[q.Y, q.X].ScoreB;
      _Push(queue, node, data, size);
    end;
  end;

  Result := [];
end;

function AStarTPA(tpa: TPointArray; start, goal: TPoint; diagonalTravel: Boolean): TPointArray;
const
  OFFSETS: array[0..7] of TPoint = ((X:0; Y:-1),(X:-1; Y:0),(X:1; Y:0),(X:0; Y:1),(X:1; Y:-1),(X:-1; Y:1),(X:1; Y:1),(X:-1; Y:-1));
var
  b: TBox;
  queue: TQueue;
  data: TAStarData;
  matrix: T2DBoolArray;
  score, i, hi, size: Int32;
  node: TNode;
  tl, q, p: TPoint;
begin
  b := GetTPABounds(tpa);
  if not b.Contains(start) then Exit;
  if not b.Contains(goal) then Exit;

  tl.X := b.X1;
  tl.Y := b.Y1;
  start.X -= tl.X;
  start.Y -= tl.Y;
  goal.X -= tl.X;
  goal.Y -= tl.Y;

  b.X1 := 0;
  b.Y1 := 0;
  b.X2 -= tl.X;
  b.Y2 -= tl.Y;

  SetLength(matrix, b.Y2+1, b.X2+1);

  for i := 0 to High(tpa) do
  begin
    tpa[i].X -= tl.X;
    tpa[i].Y -= tl.Y;
    matrix[tpa[i].Y, tpa[i].X] := True;
  end;

  if not matrix[start.Y, start.X] then Exit;
  if not matrix[goal.Y, goal.X] then Exit;

  SetLength(data, b.Y2 + 1, b.X2 + 1);

  data[start.Y, start.X].ScoreB := Sqr(start.X - goal.X) + Sqr(start.Y - goal.Y);

  node.Pt := start;
  node.Weight := data[start.Y, start.X].ScoreB;
  _Push(queue, node, data, size);

  if diagonalTravel then hi := 7 else hi := 3;

  while (size > 0) do
  begin
    node := _Pop(queue, data, size);
    p := node.Pt;

    if p = goal then Exit(_BuildPath(start, goal, data, tl));

    for i := 0 to hi do
    begin
      q := p + OFFSETS[i];

      if not b.Contains(q) then Continue;
      if not matrix[q.Y, q.X] then Continue;

      score := data[p.Y, p.X].ScoreA + 1;

      if data[q.Y, q.X].Closed and (score >= data[q.Y, q.X].ScoreA) then
        Continue;
      if data[q.Y, q.X].Open and (score >= data[q.Y, q.X].ScoreA) then
        Continue;

      data[q.Y, q.X].Parent := p;
      data[q.Y, q.X].ScoreA := score;
      data[q.Y, q.X].ScoreB := data[q.Y, q.X].ScoreA + Sqr(q.X - goal.X) + Sqr(q.Y - goal.Y);;

      if data[q.Y, q.X].Open then Continue;

      node.Pt := q;
      node.Weight := data[q.Y, q.X].ScoreB;
      _Push(queue, node, data, size);
    end;
  end;

  Result := [];
end;

end.

