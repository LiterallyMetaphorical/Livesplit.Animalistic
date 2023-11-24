state ("Animalistic-Win64-Shipping") 
{
    //float IGTBackup : 0x0468E660, 0x20, 0x18, 0x4A0, 0x30, 0x60, 0x194;
    int EndScreen : 0x4C2AE74;
}

init
{
    // Scanning the MainModule for static pointers to GSyncLoadCount, UWorld, UEngine and FNamePool
    var scn = new SignatureScanner(game, game.MainModule.BaseAddress, game.MainModule.ModuleMemorySize);
    var syncLoadTrg = new SigScanTarget(5, "89 43 60 8B 05 ?? ?? ?? ??") { OnFound = (p, s, ptr) => ptr + 0x4 + game.ReadValue<int>(ptr) };
    var syncLoadCounterPtr = scn.Scan(syncLoadTrg);

    //sig scan for loaded map lol idk what else to write here
    var loadedMapBaseAddress = scn.Scan(new SigScanTarget(3, "488B??????????E8????????488D??????????E8????????8B????39") { OnFound = (p, s, ptr) => ptr + 0x4 + game.ReadValue<int>(ptr) });
    var loadedMapPointer = new DeepPointer (loadedMapBaseAddress, 0x8B0, 0x0);

    vars.Watchers = new MemoryWatcherList
    {
        // GSyncLoadCount
        new MemoryWatcher<int>(new DeepPointer(syncLoadCounterPtr)) { Name = "syncLoadCount" },
        // GWorld
        new StringWatcher(loadedMapPointer,150) { Name = "loadedMap"},
    };

    vars.doneMaps = new List<string>();

    vars.Watchers.UpdateAll(game);

    //helps to fix errors for old states of the sigscan
    current.loadedMap = "";

    //sets var loading from the memory watcher
    current.loading = old.loading = vars.Watchers["syncLoadCount"].Current > 0;
}

startup
  {
		if (timer.CurrentTimingMethod == TimingMethod.RealTime)
// Asks user to change to game time if LiveSplit is currently set to Real Time.
    {        
        var timingMessage = MessageBox.Show (
            "This game uses Time without Loads (Game Time) as the main timing method.\n"+
            "LiveSplit is currently set to show Real Time (RTA).\n"+
            "Would you like to set the timing method to Game Time?",
            "LiveSplit | Animalistic",
            MessageBoxButtons.YesNo,MessageBoxIcon.Question
        );
        
        if (timingMessage == DialogResult.Yes)
        {
            timer.CurrentTimingMethod = TimingMethod.GameTime;
        }
    }

    //creates text components for variable information
	vars.SetTextComponent = (Action<string, string>)((id, text) =>
	{
	        var textSettings = timer.Layout.Components.Where(x => x.GetType().Name == "TextComponent").Select(x => x.GetType().GetProperty("Settings").GetValue(x, null));
	        var textSetting = textSettings.FirstOrDefault(x => (x.GetType().GetProperty("Text1").GetValue(x, null) as string) == id);
	        if (textSetting == null)
	        {
	        var textComponentAssembly = Assembly.LoadFrom("Components\\LiveSplit.Text.dll");
	        var textComponent = Activator.CreateInstance(textComponentAssembly.GetType("LiveSplit.UI.Components.TextComponent"), timer);
	        timer.Layout.LayoutComponents.Add(new LiveSplit.UI.Components.LayoutComponent("LiveSplit.Text.dll", textComponent as LiveSplit.UI.Components.IComponent));
	
	        textSetting = textComponent.GetType().GetProperty("Settings", BindingFlags.Instance | BindingFlags.Public).GetValue(textComponent, null);
	        textSetting.GetType().GetProperty("Text1").SetValue(textSetting, id);
	        }
	
	        if (textSetting != null)
	        textSetting.GetType().GetProperty("Text2").SetValue(textSetting, text);
    });
}

update
{ 
    vars.Watchers.UpdateAll(game);

    // The game is considered to be loading if any scenes are loading synchronously
    current.loading = vars.Watchers["syncLoadCount"].Current > 0;
    current.loadedMap = vars.Watchers["loadedMap"].Current;
    //print(current.loading.ToString());
    //print(modules.First().ModuleMemorySize.ToString());
}

start
{
    if
    (
        old.loadedMap == "/Game/Maps/New_MainMenu" && current.loadedMap != "/Game/Maps/New_MainMenu"
    )  
        return true;
}

split
{
	return old.loadedMap != current.loadedMap && current.loadedMap != "/Game/Maps/New_MainMenu";
}

isLoading 
{
	return current.loading || current.EndScreen == 3;
}

exit
{
    timer.IsGameTimePaused = true;
}