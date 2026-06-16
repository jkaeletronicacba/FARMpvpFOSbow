uses
  SysUtils, Classes;

const
  k   = 1000;     // Multiplicador. Nao tocar.
  kk  = 1000000;  // Multiplicador. Nao tocar.
  mnt = 60000;    // Multiplicador. Nao tocar.

  // Raio de ataque. Se o alvo sair deste raio, o PVP para.
  Radio = 5000;

var
  Item: TL2Item;
  Npc: TL2Npc;
  Buff: TL2Buff;
  Skill: TL2Skill;
  DateTime: TDateTime;

  horas, minutos, segundos, milisegundos, dia: Word;
  i, j, r, c: Integer;

  MyName, PVPTargetName: string;

  // Lista de chars para atacar imediatamente.
  CharWarList: array of string = [
    'pituf0','pegamucho','oblix','mortifago','lastdwarfspoil','wirek',
    'sweetdina','goleador2','goleador1','Javelina','katina','ilililiilliil',
    'euterpi','yougoodtogo','luckylee','yabadabadu','lililili','enchantra',
    'megamente','zmpoutsam','lookwhatifind','Mortifago','littleraidboss',
    'nuze','MatthewFlorida','suse','s1l1','fedora','shentai','GNU','Blanina',
    'otrobulto','mhtsiaspoil','litleraidboss','BombaCha','Fantastic4',
    'BufferBooster','SERVERPUTO','MissPoronga','StinK','LecoRJ','DUDYY',
    'W0RGG','MrBoss','GASMONKEY','g0iNbuLIlit02','DigBick','gramin',
    'sp0il3r3k','kuku8','shentai','recipers','KROSNOludek','GiantRatBoo',
    'Tazzar','xxXsplXxx','Struzanka','CzlowiekCzolg','Oktisanka','xxgussxx',
    'FranekKowadlo','Tatianamyrca','Cebulcia','[ARE]SSSSS','BlankaPL',
    'Labunistanka1','Nemadon','Podgorcanka','BellaCiao','G1L3','LaPonky',
    'buscadora','T0rtaz0s','ilugano','GodQueen','TrullyBully','Plana',
    'BgAdventure','GnomikONA','NumerJeden','XGaticaX','Miohi','SmalBaby'
  ];

  OutCity, NpcBufferOn, ServicePVP, ServiceIfDead, ServiceTeleport,
  ServiceIfNeedBuff, OnCombat, ZoneInCity, ZoneGrocerNPC, ZoneGrocerPort,
  ZoneGrocerLadder, ZoneFrontGrocer, ZoneFountainGrocer, ZoneMagor,
  ZoneGKFront, ZoneGK, ZonePet, ZonePet2, ZoneTeleportHellbound,
  ZoneTeleportHellbound2, PvpSettingLoaded: Boolean;


// Retorna hora atual formatada para mensagens.
function Agora: string;
var
  CurrentTime: TDateTime;
begin
  CurrentTime := Now;
  DecodeTime(CurrentTime, horas, minutos, segundos, milisegundos);
  Result := FormatDateTime('mm/dd'', ''hh:nn:ss: ', CurrentTime);
end;


// Verifica se uma string existe dentro de um array de strings.
function StrInArray(s: string; a: array of string): Boolean;
var
  idx: Integer;
begin
  Result := False;

  for idx := Low(a) to High(a) do
  begin
    if LowerCase(s) = LowerCase(a[idx]) then
    begin
      Result := True;
      Break;
    end;
  end;
end;


// Procura um char pelo nome dentro da CharList.
// Retorna -1 se nao encontrar.
function FindCharIndexByName(CharName: string): Integer;
var
  idx: Integer;
begin
  Result := -1;

  for idx := 0 to CharList.Count - 1 do
  begin
    if LowerCase(CharList(idx).Name) = LowerCase(CharName) then
    begin
      Result := idx;
      Break;
    end;
  end;
end;


// Carrega configuracao normal de farm, se existir.
procedure LoadFarmConfig;
begin
  if FileExists(ExePath + '\Settings\' + MyName + '.xml') then
  begin
    Engine.LoadConfig(MyName + '.xml');
    print('Configuracao de farm carregada');
  end
  else
    print('Configuracao de farm nao encontrada: ' + MyName + '.xml');
end;


// Carrega configuracao de PVP, se existir.
procedure LoadPvpConfig;
begin
  if FileExists(ExePath + '\Settings\' + MyName + 'PVP.xml') then
  begin
    Engine.LoadConfig(MyName + 'PVP.xml');
    PvpSettingLoaded := True;
    print('Configuracao de PVP carregada');
  end
  else
    print('Configuracao de PVP nao encontrada: ' + MyName + 'PVP.xml');
end;


// Controle quando morrer.
procedure ThreadIfDead;
begin
  print('Servico IfDead iniciado');
  ServiceIfDead := True;

  repeat
    if User.Dead then
    begin
      Engine.FaceControl(0, False);
      Delay(2 * k);

      print('Morri. Voltando para a cidade.');
      Engine.GoHome;
      Delay(5 * k);

      LoadFarmConfig;
    end;

    Delay(1 * k);
  until ZoneInCity;

  ServiceIfDead := False;
  print('Servico IfDead finalizado');
end;


// Controle de PVP.
procedure ThreadCombatActions;
var
  TargetIndex: Integer;
begin
  print('Servico CombatActions iniciado');
  ServicePVP := True;
  r := Radio;

  repeat
    Engine.FaceControl(0, True);

    for c := 0 to CharList.Count - 1 do
    begin
      if (not ZoneInCity)
      and StrInArray(CharList(c).Name, CharWarList)
      and (User.DistTo(CharList(c)) < r) then
      begin
        PVPTargetName := CharList(c).Name;
        print('Char war ' + PVPTargetName + ' em range');
        OnCombat := True;
      end;

      if (not ZoneInCity)
      and (CharList(c).Target.Name = MyName)
      and (not CharList(c).IsMember)
      and (User.DistTo(CharList(c)) < r) then
      begin
        PVPTargetName := CharList(c).Name;
        print('Estou no target de ' + PVPTargetName + ' e ele esta em range');
        OnCombat := True;
      end;

      if OnCombat then
      begin
        Engine.AutoSoulShot('Soulshot (S-grade)', True);
        print(Agora + ' Entrei em PVP com ' + PVPTargetName);

        if not PvpSettingLoaded then
          LoadPvpConfig;
      end;

      while OnCombat do
      begin
        TargetIndex := FindCharIndexByName(PVPTargetName);

        if TargetIndex = -1 then
        begin
          print('Alvo nao encontrado na CharList: ' + PVPTargetName);
          OnCombat := False;
          Break;
        end;

        Engine.SetTarget(PVPTargetName);
        Delay(100);

        if User.Target.IsMember then
        begin
          Engine.CancelTarget;
          OnCombat := False;
          Break;
        end;

        if User.DistTo(CharList(TargetIndex)) > r then
        begin
          print(PVPTargetName + ' saiu do range');
          OnCombat := False;
          Break;
        end;

        if User.Dead then
        begin
          OnCombat := False;
          Break;
        end;

        if User.Target.Dead then
        begin
          OnCombat := False;
          Engine.CancelTarget;
          print(PVPTargetName + ' caiu ;)');
          Break;
        end;

        // Usa a tecla 1 do teclado para atacar/usar skill configurada.
        Engine.UseKey(49);
        Delay(500);
      end;
    end;

    if (not OnCombat) and PvpSettingLoaded then
    begin
      LoadFarmConfig;
      Engine.AutoSoulShot('Soulshot (S-grade)', False);
      PvpSettingLoaded := False;
    end;

    Delay(1 * k);
  until ZoneInCity;

  ServicePVP := False;
  print('Servico CombatActions finalizado');
end;


// Verifica se precisa voltar para buff.
procedure ThreadIfNeedBuff;
begin
  print('Servico IfNeedBuff iniciado');
  ServiceIfNeedBuff := True;

  repeat
    if (not User.Buffs.ByID(28000, Buff)) and NpcBufferOn then
    begin
      while User.InCombat do
      begin
        Engine.FaceControl(0, False);
        Engine.Attack;
        Delay(1 * k);
      end;

      print('Estou sem buff. Vou usar Scroll of Escape.');
      Engine.UseItem('Scroll of Escape');
      Delay(20 * k);
    end;

    Delay(1 * k);
  until ZoneInCity or (not NpcBufferOn);

  ServiceIfNeedBuff := False;
  print('Servico IfNeedBuff finalizado');
end;


// Atualiza as zonas onde o char esta.
procedure ThreadLocations;
begin
  print('Servico Locations iniciado');

  repeat
    ZoneInCity := User.InRange(111381, 219311, -3572, 10 * k);

    ZoneGrocerNPC := User.InRange(107114, 216770, -3592, 150);
    ZoneGrocerPort := User.InRange(107101, 217191, -3622, 150);
    ZoneGrocerLadder := User.InRange(107105, 217949, -3691, 150);
    ZoneFrontGrocer := User.InRange(107384, 218165, -3701, 150);
    ZoneFountainGrocer := User.InRange(107889, 218010, -3701, 900);

    ZoneMagor := User.InRange(110356, 220164, -3626, 150);

    ZonePet := User.InRange(110766, 219788, -3697, 350);
    ZonePet2 := User.InRange(110788, 220692, -3697, 350);

    ZoneTeleportHellbound := User.InRange(111929, 219563, -3697, 350);
    ZoneTeleportHellbound2 := User.InRange(112098, 220577, -3697, 350);

    ZoneGKFront := User.InRange(111388, 219157, -3568, 150);
    ZoneGK := User.InRange(111381, 219311, -3572, 150);

    Delay(250);
  until False;
end;


// Verifica horario em que o NPC buffer esta disponivel.
procedure ThreadNpcBufferState;
begin
  print('Servico NpcBufferState iniciado');

  repeat
    DateTime := Now;
    DecodeTime(DateTime, horas, minutos, segundos, milisegundos);
    dia := DayOfWeek(DateTime);

    // Domingo = 1, Segunda = 2, ..., Sabado = 7.

    if (dia = 2) or (dia = 3) or (dia = 4) or (dia = 5) then
      NpcBufferOn := True;

    if (dia = 6) and (horas < 20) then
      NpcBufferOn := True;

    if (dia = 6) and (horas >= 20) then
      NpcBufferOn := False;

    if dia = 7 then
      NpcBufferOn := False;

    if (dia = 1) and (horas < 20) then
      NpcBufferOn := False;

    if (dia = 1) and (horas >= 20) then
      NpcBufferOn := True;

    if NpcBufferOn then
      print('Buffer disponivel')
    else
      print('Buffer nao disponivel');

    Delay(10 * mnt);
  until False;
end;


// Faz buff no NPC, teleporta e volta a ligar o farm.
procedure BuffAndTeleport;
begin
  print('Servico BuffAndTeleport iniciado');
  ServiceTeleport := True;

  if ZoneGK then
  begin
    if NpcBufferOn then
    begin
      Engine.SetTarget(36600); // Buffer Booster
      Delay(500);
      Engine.DlgOpen;
      Delay(500);
      Engine.DlgSel(1); // Buff para magos
      Delay(500);
      Engine.DlgOpen;
      Delay(500);
      Engine.DlgSel(1); // Buff para magos
      Delay(500);
    end;

    Engine.SetTarget(30899); // GK Flauen
    Delay(500);
    Engine.DlgOpen;
    Delay(500);
    Engine.DlgSel(1);  // Teleport normal
    Delay(500);
    Engine.DlgSel(10); // Field of Silence
    Delay(4 * k);

    Engine.MoveTo(87691, 162835, -3536);
    Engine.MoveTo(89077, 163682, -3448);
    Engine.MoveTo(90862, 164738, -3368);
    Engine.MoveTo(93669, 168184, -3288);
    Engine.MoveTo(93267, 170129, -3616);
    Engine.MoveTo(91366, 172173, -3760);
    Engine.MoveTo(89483, 173939, -3688);

    LoadFarmConfig;
    Engine.AutoSoulShot('Soulshot (S-grade)', False);
    Engine.FaceControl(0, True);
  end;

  ServiceTeleport := False;
  print('Servico BuffAndTeleport finalizado');
end;


// Acoes automaticas dentro da cidade e controle de servicos fora da cidade.
procedure City_And_Farm_Zone_Actions;
begin
  print('Servico CityActions iniciado');

  repeat
    if ZoneInCity then
    begin
      Engine.AutoSoulShot('Soulshot (S-grade)', False);
      Engine.FaceControl(0, False);
    end;

    if ZoneFountainGrocer then
    begin
      // Saindo da fonte/grocery em direcao a GK.
      Engine.MoveTo(107677, 217786, -3701);
      Engine.MoveTo(107894, 217572, -3701);
      Engine.MoveTo(109226, 217485, -3767);
      Engine.MoveTo(110065, 217299, -3775);
      Engine.MoveTo(110092, 218984, -3506);
      Engine.MoveTo(111293, 219146, -3569);
      Engine.MoveTo(111429, 219380, -3572);
    end;

    if ZonePet then
    begin
      // Saindo do Pet Manager em direcao a GK.
      Engine.MoveTo(111205, 219777, -3697);
      Engine.MoveTo(111220, 219327, -3572);
      Engine.MoveTo(111403, 219352, -3572);
      Delay(500);
    end;

    if ZonePet2 then
    begin
      // Saindo do segundo Pet Manager em direcao a GK.
      Engine.MoveTo(111205, 219777, -3697);
      Engine.MoveTo(111220, 219327, -3572);
      Engine.MoveTo(111403, 219352, -3572);
      Delay(500);
    end;

    if ZoneTeleportHellbound then
    begin
      // Saindo do teleport Hellbound em direcao a GK.
      Engine.MoveTo(111205, 219777, -3697);
      Engine.MoveTo(111220, 219327, -3572);
      Engine.MoveTo(111403, 219352, -3572);
      Delay(500);
    end;

    if ZoneTeleportHellbound2 then
    begin
      // Saindo do segundo teleport Hellbound em direcao a GK.
      Engine.MoveTo(111205, 219777, -3697);
      Engine.MoveTo(111220, 219327, -3572);
      Engine.MoveTo(111403, 219352, -3572);
      Delay(500);
    end;

    if ZoneGK and (not ServiceTeleport) then
      BuffAndTeleport;

    if (not ZoneInCity) and (not ServiceIfNeedBuff) and NpcBufferOn then
      Script.NewThread(@ThreadIfNeedBuff);

    if (not ZoneInCity) and (not ServiceIfDead) then
      Script.NewThread(@ThreadIfDead);

    if (not ZoneInCity) and (not ServicePVP) then
      Script.NewThread(@ThreadCombatActions);

    Delay(1 * k);
  until False;

  print('Servico CityActions finalizado');
end;


// Inicio do script.
begin
  MyName := User.Name;

  PvpSettingLoaded := False;
  ServicePVP := False;
  ServiceIfDead := False;
  ServiceTeleport := False;
  ServiceIfNeedBuff := False;
  OnCombat := False;

  Script.NewThread(@ThreadLocations);
  Script.NewThread(@ThreadNpcBufferState);

  Delay(1 * k);

  City_And_Farm_Zone_Actions;
end.
