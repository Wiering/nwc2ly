program nwc2ly;

{
  nwc2ly - program to convert music from NoteWorthy Composer to Lilypond,
  to be used as a User Tool (requires NoteWorthy Composer 2)


  Copyright (c) 2004, Mike Wiering, Wiering Software
  All rights reserved.

  Redistribution and use in source and binary forms, with or without modification, 
  are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this
	  list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice,
	  this list of conditions and the following disclaimer in the documentation
	  and/or other materials provided with the distribution.
    * Neither the name of Wiering Software nor the names of its contributors may
	  be used to endorse or promote products derived from this software without
	  specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
  INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
  POSSIBILITY OF SUCH DAMAGE.

  History:

    19 may 2005   0.21   Mike Wiering     Bug fix: triplets, cresc
                                          Added: rehearsal marks
    22 dec 2004   0.20   Mike Wiering     Ported to Lilypond 2.4
    17 dec 2004   0.11   Mike Wiering     Added grace notes
     1 dec 2004   0.11   Mike Wiering     Bug fix: naturals, added fermatas
    24 nov 2004   0.10   Mike Wiering     Original version (for Lilypond 2.2)

}

{$APPTYPE CONSOLE}

  uses
    SysUtils;

  const
    VERSION = '0.21';

  var
    Key: array['A'..'G'] of Char;
    BarKey: array['A'..'G'] of Char;
    LastKey: array['A'..'G'] of Char;

  var
    Output: string;

  var
    CrescEndPos: Integer;

  procedure Write (Txt: string);
  begin
    Output := Output + Txt;
  end;

  procedure WriteLn (Txt: string);
  begin
    Write (Txt + #13#10);
  end;


  function SetKeySig (s: string): string;
    var
      i, j: Integer;
      c: Char;
      Sharps, Flats: Integer;
  begin
    for c := 'A' to 'G' do
      Key[c] := 'n';
    Sharps := 0;
    Flats := 0;
    while s <> '' do
    begin
      c := s[1];
      Key[c] := s[2];
      if s[2] = '#' then Inc (Sharps);
      if s[2] = 'b' then Inc (Flats);
      Delete (s, 1, 3);
    end;
    case Sharps - Flats of
      -7: s := 'as\minor';
      -6: s := 'es\minor';
      -5: s := 'bes\minor';
      -4: s := 'f\minor';
      -3: s := 'c\minor';
      -2: s := 'g\minor';
      -1: s := 'd\minor';
       0: s := 'c\major';
       1: s := 'g\major';
       2: s := 'd\major';
       3: s := 'a\major';
       4: s := 'e\major';
       5: s := 'b\major';
       6: s := 'fis\major';
       7: s := 'cis\major';
    end;
    Result := s;
  end;


  function GetCommand (var Line: string): string;
    var
      s: string;
  begin
    s := '';
    if Line[1] = '|' then
    begin
      Delete (Line, 1, 1);
      repeat
        s := s + Line[1];
        Delete (Line, 1, 1);
      until (Line = '') or (Line[1] = '|');
    end;
    GetCommand := s;
  end;

  function GetPar (ParName: string; Line: string; All: Boolean = FALSE): string;
    var
      i: Integer;
      s: string;
      Stop: set of Char;
  begin
    if All then
      Stop := ['|']
    else
      Stop := ['|', ','];
    s := '';
    i := Pos (ParName + ':', Line);
    if i > 0 then
    begin
      i := i + 1 + Length (ParName);
      while (i <= Length (Line)) and (not (Line[i] in Stop)) do
      begin
        s := s + Line[i];
        i := i + 1;
      end;
    end;
    GetPar := s;
  end;

  function GetVal (s: string): Integer;
    var
      i, j: Integer;
  begin
    Val (s, i, j);
    if j <> 0 then
      i := 0;
    GetVal := i;
  end;


  function ReadNextLine: string;
    var
      s: string;
  begin
    repeat
      ReadLn (Input, s);
    until (Pos ('Visibility:Never', s) = 0) or Eof (Input);
    Result := s;
  end;



  var
    Last, Line, Cmd, Note, s1, s2, s3, s4, s5: string;
    CurClef: string;
    FromC: Integer;
    i, j, N, Code: Integer;
    Slur: Boolean;
    Tied: Boolean;
    Grace: Boolean;
    Dyn: string;
    Chord: string;
    LastCresc: Integer;
    c: Char;
    BarNo: Integer;
    Fermata: Boolean;
    NextText: string;

  procedure CheckCresc;
    var
      bCresc, bDeCresc: Boolean;
  begin
    bCresc := Pos ('Crescendo', GetPar ('Opts', Line, TRUE)) > 0;
    bDeCresc := Pos ('Diminuendo', GetPar ('Opts', Line, TRUE)) > 0;

    if Abs (LastCresc) = 1 then
    begin
      if not (bCresc or bDeCresc) then
      begin
        if CrescEndPos <> -1 then
        begin
          Insert ('\! ', Output, CrescEndPos);
          CrescEndPos := -1;
        end
        else
          Write ('\! ');
        LastCresc := 0;
      end
      else
        CrescEndPos := Length (Output) + 1;
    end;

    if LastCresc = 3 then
    begin
      Write ('\< ');
      LastCresc := 2;
    end;

    if LastCresc = -3 then
    begin
      Write ('\> ');
      LastCresc := -2;
    end;

    if bCresc then
      if LastCresc <> 1 then
      begin
        if LastCresc = -1 then
          Write ('\! ');
       // Write ('\setHairpinCresc ');
        Write ('\< ');
        LastCresc := 1;
        CrescEndPos := -1;
      end;

    if bDeCresc then
      if LastCresc <> -1 then
      begin
        if LastCresc = 1 then
          Write ('\! ');
       // Write ('\setHairpinCresc ');
        Write ('\> ');
        LastCresc := -1;
        CrescEndPos := -1;
      end;
  end;

begin
  CrescEndPos := -1;
  Output := '';
  NextText := '';
  WriteLn ('% Generated by nwc2ly version ' + VERSION + ' http://nwc2ly.sf.net/'#13#10);
  WriteLn ('\version "2.4.0"');
  WriteLn ('\header {');

  WriteLn ('  title = "Title"');
  WriteLn ('  subtitle = "Subtitle"');
 // WriteLn ('  subsubtitle = "Subsubtitle"');
 // WriteLn ('  dedication = "Dedication"');
  WriteLn ('  composer = "Composer"');
  WriteLn ('  instrument = "Instrument"');
 // WriteLn ('  arranger = "Arranger"');
 // WriteLn ('  poet = "Poet"');
 // WriteLn ('  texttranslator = "Translator"');
  WriteLn ('  copyright = "Copyright"');
 // WriteLn ('  source = "source"');
 // WriteLn ('  enteredby = "entered by"');
 // WriteLn ('  maintainerEmail = "email"');
 // WriteLn ('  texidoc = "texidoc"');
  WriteLn ('}');
  WriteLn ('');
  WriteLn ('\score {');
  WriteLn (' \header {');
 // WriteLn ('  opus = "Opus 0"');
  WriteLn ('  piece = "Piece"');
  WriteLn (' }');
  WriteLn (' {');
  WriteLn (' #(set-accidental-style '#39'modern-cautionary)');

  CurClef := 'treble';
  SetKeySig ('');
  Slur := FALSE;
  Tied := FALSE;
  Grace := FALSE;
  Dyn := '';
  LastCresc := 0;
  for c := 'A' to 'G' do
    BarKey[c] := #0;
  for c := 'A' to 'G' do
    LastKey[c] := #0;
  BarNo := 1;
  Fermata := FALSE;

  ReadLn (Input, Line);
  if Line <> '!NoteWorthyComposerClip(2.0,Single)' then
    WriteLn ('*** Unknown format ***');

  Line := ReadNextLine;
  while (Line <> '!NoteWorthyComposerClip-End') and (not Eof (Input)) do
  begin
    Last := Line;

    Cmd := GetCommand (Line);

    if Cmd = 'Clef' then
    begin
      s1 := GetPar ('Type', Line);
      s1[1] := Chr (Ord (s1[1]) + $20);
      s2 := GetPar ('OctaveShift', Line);
      CurClef := s1;
      if s2 = 'Octave Up' then s1 := s1 + '^8';
      if s2 = 'Octave Down' then s1 := s1 + '_8';
      WriteLn (' \clef ' + s1);

      Last := '';
    end;

    if Cmd = 'Key' then
    begin
      s1 := GetPar ('Signature', Line, TRUE);
      s1 := SetKeySig (s1);
      WriteLn (' \key ' + s1);
      Last := '';
      for c := 'A' to 'G' do
        BarKey[c] := #0;
      for c := 'A' to 'G' do
        LastKey[c] := #0;
    end;

    if Cmd = 'Dynamic' then
    begin
      Dyn := '';

      if Abs (LastCresc) <> 0 then
      begin
        Dyn := '\! ';
        LastCresc := 0;
      end;

      Dyn := Dyn + '\' + GetPar ('Style', Line, TRUE);
      Last := '';
    end;

    if Cmd = 'TimeSig' then
    begin
      s1 := GetPar ('Signature', Line);
      if s1 = 'Common' then s1 := '4/4';
      if s1 = 'AllaBreve' then s1 := '2/2';
      WriteLn (' \time ' + s1);
      Last := '';
    end;

    if (Cmd = 'Note') or (Cmd = 'Chord') then
    begin
  ////    CheckCresc;

      if Pos ('Triplet=First', Line) > 0 then
        Write ('\times 2/3 { ');

      if Grace then
      begin
        if Pos ('Grace', Line) = 0 then
        begin
         // Write (' \appoggiatura ');
          Write (' } ');
          Grace := FALSE;
        end;
      end
      else
        if Pos ('Grace', Line) > 0 then
        begin
        //  Write (' \acciaccatura ');
          Write (' \acciaccatura { ');
          Grace := TRUE;
        end;

      s3 := GetPar ('Dur', Line);
      s4 := '';
      if s3 = 'Whole' then s3 := '1';
      if s3 = 'Half' then s3 := '2';
      if s3[1] in ['0'..'9'] then
        for i := Length (s3) downto 1 do
          if not (s3[i] in ['0'..'9']) then
            Delete (s3, i, 1);
      if Pos ('Dotted', Line) > 0 then s4 := '.';
      if Pos ('DblDotted', Line) > 0 then s4 := '..';

      FromC := 0;
      if CurClef = 'treble' then FromC := 6;
      if CurClef = 'bass' then FromC := -6;
      if CurClef = 'alto' then FromC := 0;
      if CurClef = 'tenor' then FromC := 2;

      chord := GetPar ('Pos', Line, TRUE);

      if Cmd = 'Chord' then Write ('<');

      repeat
        s1 := '';
        repeat
          s1 := s1 + chord[1];
          Delete (chord, 1, 1);
        until (chord = '') or (chord[1] = ',');
        if (chord <> '') then
          if (chord[1] = ',') then
            Delete (chord, 1, 1);

        if s1[Length (s1)] = '^' then
        begin
          Tied := TRUE;
          Delete (s1, Length (s1), 1);
        end;

        s5 := '';
        if s1[1] = '+' then Delete (s1, 1, 1);
        if s1[1] in ['#', 'n', 'b', 'x', 'v'] then
        begin
          s5 := s1[1];
          Delete (s1, 1, 1);
        end;

        Val (s1, N, Code);
        N := N + FromC;
        Note := Chr (Ord ('a') + ((N + 2 + 70) mod 7));

        s2 := '';
        case (70 + N) div 7 - 10 of
         -5: s2 := ',,,,';
         -4: s2 := ',,,';
         -3: s2 := ',,';
         -2: s2 := ',';
         -1: ;
          0: s2 := #39;
          1: s2 := #39#39;
          2: s2 := #39#39#39;
          3: s2 := #39#39#39#39;
          4: s2 := #39#39#39#39#39;
        end;

        if s5 = '' then s5 := BarKey[UpCase (Note[1])];
        if s5 = #0 then s5 := Key[UpCase (Note[1])];

        if s5 = '#' then Note := Note + 'is';
        if s5 = 'x' then Note := Note + 'isis';
        if s5 = 'b' then Note := Note + 'es';
        if s5 = 'v' then Note := Note + 'eses';

        if (Length (Note) > 1) or (s5 = 'n') then
        begin
          BarKey[UpCase (Note[1])] := s5[1];
          LastKey[UpCase (Note[1])] := s5[1];
        end
        else
        begin
          LastKey[UpCase (Note[1])] := #0;
        end;

        Write (' ' + Note + s2);  { octave }

      until Chord = '';

      if Cmd = 'Chord' then Write ('>');

      Write (s3 + s4);  { duration }

      if Pos ('Staccato', Line) > 0 then
        Write ('-.');
      if Pos ('Accent', Line) > 0 then
        Write ('->');

      if NextText <> '' then
      begin
        Write (NextText);
        NextText := '';
      end;

      if Fermata then
      begin
        Write ('\fermata ');
        Fermata := FALSE;
      end;

      if Dyn <> '' then
      begin
        Write (Dyn + ' ');
        Dyn := '';
      end;

      if Tied then
      begin
        Write (' ~ ');
        Tied := FALSE;
      end;

      if Pos ('Slur', Line) > 0 then
        if Slur = FALSE then
        begin
          Write (' ( ');
          Slur := TRUE;
        end;

      if Slur then
        if Pos ('Slur', Line) = 0 then
        begin
          Write (' ) ');
          Slur := FALSE;
        end;

      CheckCresc;

      if Pos ('Beam=First', Line) > 0 then
        Write (' [ ');
      if Pos ('Beam=End', Line) > 0 then
        Write (' ] ');

      if Pos ('Triplet=End', Line) > 0 then
        Write (' } ');

      Last := '';
    end;

    if Cmd = 'Rest' then
    begin
      s1 := GetPar ('Dur', Line);
      s2 := '';
      if s1 = 'Whole' then s1 := '1';
      if s1 = 'Half' then s1 := '2';
      if s1[1] in ['0'..'9'] then
        for i := Length (s1) downto 1 do
          if not (s1[i] in ['0'..'9']) then
            Delete (s1, i, 1);
      if Pos ('Dotted', Line) > 0 then s2 := '.';
      if Pos ('DblDotted', Line) > 0 then s2 := '..';
      Write (' r' + s1 + s2 + ' ');

      if Fermata then
      begin
        Write ('\fermata ');
        Fermata := FALSE;
      end;

      CheckCresc;

      Last := '';
    end;

    if Cmd = 'DynamicVariance' then
    begin
      s1 := GetPar ('Style', Line);
      if s1 = 'Crescendo' then
      begin
        Write ('\setTextCresc ');
        LastCresc := 3;
      end;
      if s1 = 'Decrescendo' then
      begin
        Write ('\setTextCresc ');
        LastCresc := -3;
      end;
      Last := '';
    end;

    if Cmd = 'Tempo' then
    begin
      s1 := GetPar ('Base', Line);
      if s1 = 'Half' then s1 := '2';
      if s1 = 'Half Dotted' then s1 := '2.';
      if s1 = 'Quarter' then s1 := '4';
      if s1 = 'Quarter Dotted' then s1 := '4.';
      if s1 = 'Eighth' then s1 := '8';
      if s1 = 'Eighth Dotted' then s1 := '8.';
      if s1 = '' then s1 := '4';
      WriteLn (' \tempo ' + s1 + '=' + GetPar ('Tempo', Line));
      Last := '';
    end;

    if Cmd = 'TempoVariance' then
    begin
      s1 := GetPar ('Style', Line);
      if s1 = 'Fermata' then
        Fermata := TRUE;
      if s1 = 'Ritenuto' then
        NextText := '^\markup{\italic{ rit. }}' + NextText;
      Last := '';
    end;

    if Cmd = 'Text' then   {  |Text|Text:"A"|Font:User1|Pos:10 *** }
    begin
      s1 := GetPar ('Text', Line, TRUE);
      if (Length (s1) = 3) then
      begin
        if (s1[2] in ['A'..'Z']) then
          Write (' \mark \default ')
        else
          if (s1[2] = 't') then
            NextText := '-\upbow ' + NextText
          else
            if (s1[2] = 'u') then
              NextText := '-\downbow ' + NextText;
        Last := '';
      end
      else
      begin
        Delete (s1, 1, 1);
        Delete (s1, Length (s1), 1);
        i := GetVal (GetPar ('Pos', Line));
        s2 := '-';
        if i < -5 then s2 := '_';
        if i > 5 then s2 := '^';
        NextText := s2 + '\markup{\italic{ ' + s1 + ' }} ';
        Last := '';
      end;
    end;



    if Cmd = 'Bar' then
    begin
      for c := 'A' to 'G' do
        BarKey[c] := #0;
      s1 := GetPar ('Style', Line);
     // if s1 = '' then s1 := '|';
      if s1 = 'Single' then s1 := '|';
      if s1 = 'Double' then s1 := '||';
      if s1 = 'SectionOpen' then s1 := '.|';
      if s1 = 'SectionClose' then s1 := '|.';
      if s1 = 'MasterRepeatOpen' then s1 := '|:';
      if s1 = 'MasterRepeatClose' then s1 := ':|';
      if s1 = 'LocalRepeatOpen' then s1 := '|:';
      if s1 = 'LocalRepeatClose' then s1 := ':|';
      if s1 = '' then
        Write (' |')
      else
        Write (' \bar "' + s1 + '"');
      WriteLn ('  % ' + IntToStr (BarNo));
      Inc (BarNo);
      Last := '';
    end;

    if Last <> '' then
    begin
      WriteLn ('');
      WriteLn ('% *** ' + Last + ' ***');
      WriteLn ('');
    end;

    Line := ReadNextLine;
  end;

  CheckCresc;

  WriteLn (' \bar "|."');
  WriteLn (' }');
  WriteLn ('}');

  System.Write (Output);

  Halt (99);  { report to user }
end.
