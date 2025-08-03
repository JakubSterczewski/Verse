# Code by JakubSterczewski – github.com/JakubSterczewski
# Licensed under MIT with attribution requirement – see LICENSE

using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Playspaces }
using { /Verse.org/Simulation }
using { /Fortnite.com/Game }
using { /Fortnite.com/FortPlayerUtilities }
using { /UnrealEngine.com/Temporary/SpatialMath }

HideAndSeek := class(creative_device):
    @editable var StartButton : button_device = button_device {}
    @editable var StartTeleporter : teleporter_device = teleporter_device {}
    @editable var HidingTimer : timer_device = timer_device {}
    @editable var EndTimer : timer_device = timer_device {}
    @editable var WeaponGranter : item_granter_device = item_granter_device {}

    @editable var SeekerMessage : hud_message_device = hud_message_device {}
    @editable var HiderMessage : hud_message_device = hud_message_device {}
    @editable var TeamSeekers : team_settings_and_inventory_device = team_settings_and_inventory_device {}
    @editable var TeamHiders : team_settings_and_inventory_device = team_settings_and_inventory_device {}
    @editable var TeamSeekersChooser : class_and_team_selector_device = class_and_team_selector_device {}
    @editable var TeamHidersChooser : class_and_team_selector_device = class_and_team_selector_device {}

    var isSeeking : logic = false

    OnBegin<override>()<suspends> : void =
        StartButton.InteractedWithEvent.Subscribe(OnButtonInteracted)
        HidingTimer.SuccessEvent.Subscribe(OnHidingTimerSuccessEvent)
        EndTimer.SuccessEvent.Subscribe(OnEndTimerSuccessEvent)

    OnButtonInteracted(Agent : agent) : void =
        Print("Presssed button")
        StartButton.Disable()

        GetPlayspace().PlayerAddedEvent().Subscribe(OnJoined)
        GetPlayspace().PlayerRemovedEvent().Subscribe(OnLeft)

        AllPlayers := GetPlayspace().GetPlayers()
        for (Player : AllPlayers):
            if (Agent = Player):
                TeamSeekersChooser.ChangeTeam(Player)
                SeekerMessage.Show(Player)
                WeaponGranter.GrantItem(Player)
            else if (FortCharacter := Player.GetFortCharacter[]):
                FortCharacter.EliminatedEvent().Subscribe(OnEliminated)
                TeamHidersChooser.ChangeTeam(Player)
                HiderMessage.Show(Player)
                StartTeleporter.Teleport(Player)

    OnEliminated(Result : elimination_result) : void =
        Print("Eliminated a player")
        Eliminated := Result.EliminatedCharacter
        if (FortCharacter := Eliminated, EliminatedAgent := FortCharacter.GetAgent[]):
            TeamSeekersChooser.ChangeTeam(EliminatedAgent)
            spawn:
                AgentRespawn(EliminatedAgent)
        CheckEndgame()

    AgentRespawn(Agent : agent)<suspends> : void =
        Sleep(0.5)
        Agent.Respawn(vector3{X := StartTeleporter.GetTransform().Translation.X, Y := StartTeleporter.GetTransform().Translation.Y, Z := StartTeleporter.GetTransform().Translation.Z}, rotation{})
        if (Player := player[Agent]):
            SeekerMessage.Show(Player)
            WeaponGranter.GrantItem(Player)

    OnHidingTimerSuccessEvent(Agent : ?agent) : void =
        Print("OnHidingTimerSuccessEvent")
        set isSeeking = true
        TeamCollection := GetPlayspace().GetTeamCollection()
        Teams := TeamCollection.GetTeams()
        if (Teams.Length >= 2):
            if (Team2 := Teams[1]):
                if (Team2Players := TeamCollection.GetAgents[Team2]):
                    for (Player : Team2Players):
                        StartTeleporter.Teleport(Player)
        EndTimer.Start()

    OnEndTimerSuccessEvent(Agent : ?agent) : void =
        Print("OnEndTimerSuccessEvent")
        TeamHiders.EndRound()

    CheckEndgame() : void =
        Print("Checking endgame")
        TeamCollection := GetPlayspace().GetTeamCollection()
        Teams := TeamCollection.GetTeams()
        if (Teams.Length >= 2):
            if (Team1 := Teams[0], Team2 := Teams[1]):
                if (Team1Players := TeamCollection.GetAgents[Team1], Team2Players := TeamCollection.GetAgents[Team2]):
                    if (Team1Players.Length = 0):
                        Print("Seekers win")
                        TeamSeekers.EndRound()
                    else if (Team2Players.Length = 0):
                        Print("Hiders win")
                        TeamHiders.EndRound()

    OnLeft(Agent : agent) : void =
        Print("Player left")
        CheckEndgame()

    OnJoined(Agent : agent) : void =
        Print("Player joined")
        TeamSeekersChooser.ChangeTeam(Agent)
        SeekerMessage.Show(Agent)
        WeaponGranter.GrantItem(Agent)
        CheckEndgame()
        if (isSeeking?):
            StartTeleporter.Teleport(Agent)
