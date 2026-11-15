using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

namespace ToontownLauncher
{
    sealed class LauncherConfig
    {
        public string Address;
        public int Port;
        public string Release;

        public LauncherConfig()
        {
            Address = "";
            Port = 4343;
            Release = "";
        }

        public static LauncherConfig Load(string path)
        {
            var config = new LauncherConfig();
            if (!File.Exists(path))
                return config;
            try
            {
                var serializer = new JavaScriptSerializer();
                var root = serializer.DeserializeObject(File.ReadAllText(path)) as Dictionary<string, object>;
                if (root == null)
                    return config;
                if (root.ContainsKey("address") && root["address"] != null)
                    config.Address = root["address"].ToString();
                if (root.ContainsKey("port") && root["port"] != null)
                    config.Port = Convert.ToInt32(root["port"]);
                if (root.ContainsKey("release") && root["release"] != null)
                    config.Release = root["release"].ToString();
            }
            catch (Exception)
            {
            }
            if (config.Port < 1 || config.Port > 65535)
                config.Port = 4343;
            return config;
        }

        public void Save(string path)
        {
            var root = new Dictionary<string, object>();
            root["address"] = Address ?? "";
            root["port"] = Port;
            root["release"] = Release ?? "";
            var serializer = new JavaScriptSerializer();
            File.WriteAllText(path, serializer.Serialize(root));
        }
    }

    sealed class ReleasePack
    {
        public string Name;
        public string Url;
    }

    sealed class ReleaseInfo
    {
        public string Tag;
        public List<ReleasePack> Packs;

        public ReleaseInfo()
        {
            Packs = new List<ReleasePack>();
        }
    }

    static class ReleaseClient
    {
        const string LatestUrl = "https://api.github.com/repos/CakeGamingOfficial/Toontown-Reimagined/releases/latest";

        public static async Task<ReleaseInfo> GetLatestAsync(CancellationToken cancel)
        {
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            using (var http = new HttpClient())
            {
                http.Timeout = TimeSpan.FromSeconds(30);
                var request = new HttpRequestMessage(HttpMethod.Get, LatestUrl);
                request.Headers.TryAddWithoutValidation("User-Agent", "ToontownLauncher");
                request.Headers.TryAddWithoutValidation("Accept", "application/vnd.github+json");
                using (var response = await http.SendAsync(request, cancel))
                {
                    if (response.StatusCode == HttpStatusCode.NotFound)
                        throw new InvalidOperationException("GitHub has no release yet.");
                    if (!response.IsSuccessStatusCode)
                        throw new InvalidOperationException("GitHub returned an error (" + (int)response.StatusCode + ").");
                    var json = await response.Content.ReadAsStringAsync();
                    return Parse(json);
                }
            }
        }

        static ReleaseInfo Parse(string json)
        {
            var serializer = new JavaScriptSerializer();
            var root = serializer.DeserializeObject(json) as Dictionary<string, object>;
            if (root == null || !root.ContainsKey("tag_name") || root["tag_name"] == null)
                throw new InvalidOperationException("GitHub did not return a release.");
            var info = new ReleaseInfo();
            info.Tag = root["tag_name"].ToString().Trim();
            if (info.Tag.Length == 0)
                throw new InvalidOperationException("GitHub did not return a release.");
            var assets = root.ContainsKey("assets") ? root["assets"] as ArrayList : null;
            var seen = new Dictionary<string, bool>(StringComparer.OrdinalIgnoreCase);
            if (assets != null)
            {
                foreach (var item in assets)
                {
                    var asset = item as Dictionary<string, object>;
                    if (asset == null || !asset.ContainsKey("name") || asset["name"] == null)
                        continue;
                    var name = PackName(asset["name"].ToString());
                    if (name.Length == 0 || seen.ContainsKey(name))
                        continue;
                    if (!asset.ContainsKey("browser_download_url") || asset["browser_download_url"] == null)
                        continue;
                    var url = asset["browser_download_url"].ToString().Trim();
                    if (url.Length == 0)
                        continue;
                    var pack = new ReleasePack();
                    pack.Name = name;
                    pack.Url = url;
                    info.Packs.Add(pack);
                    seen[name] = true;
                }
            }
            info.Packs.Sort(ComparePacks);
            var hasMain = false;
            foreach (var pack in info.Packs)
            {
                if (pack.Name == "Toontown.pck")
                    hasMain = true;
            }
            if (!hasMain)
                throw new InvalidOperationException("The latest release (" + info.Tag + ") has no Toontown.pck.");
            return info;
        }

        static string PackName(string name)
        {
            if (string.IsNullOrEmpty(name))
                return "";
            var file = Path.GetFileName(name.Trim());
            if (!string.Equals(file, name.Trim(), StringComparison.Ordinal))
                return "";
            if (file.Length < 5 || !file.EndsWith(".pck", StringComparison.OrdinalIgnoreCase))
                return "";
            if (file.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0)
                return "";
            return file;
        }

        static int ComparePacks(ReleasePack a, ReleasePack b)
        {
            var aMain = a.Name == "Toontown.pck";
            var bMain = b.Name == "Toontown.pck";
            if (aMain != bMain)
                return aMain ? -1 : 1;
            return string.Compare(a.Name, b.Name, StringComparison.OrdinalIgnoreCase);
        }

        public static async Task DownloadAsync(string url, string dest, string packName, IProgress<int> progress, CancellationToken cancel)
        {
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            using (var http = new HttpClient())
            {
                http.Timeout = TimeSpan.FromHours(2);
                var request = new HttpRequestMessage(HttpMethod.Get, url);
                request.Headers.TryAddWithoutValidation("User-Agent", "ToontownLauncher");
                request.Headers.TryAddWithoutValidation("Accept", "application/octet-stream");
                using (var response = await http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, cancel))
                {
                    if (!response.IsSuccessStatusCode)
                        throw new InvalidOperationException("GitHub returned an error (" + (int)response.StatusCode + ") for " + packName + ".");
                    var total = response.Content.Headers.ContentLength.GetValueOrDefault(-1);
                    using (var input = await response.Content.ReadAsStreamAsync())
                    using (var output = new FileStream(dest, FileMode.Create, FileAccess.Write, FileShare.None))
                    {
                        var buffer = new byte[1024 * 64];
                        long got = 0;
                        var last = -1;
                        while (true)
                        {
                            var read = await input.ReadAsync(buffer, 0, buffer.Length, cancel);
                            if (read <= 0)
                                break;
                            await output.WriteAsync(buffer, 0, read, cancel);
                            got += read;
                            if (progress != null && total > 0)
                            {
                                var pct = (int)(got * 100L / total);
                                if (pct != last)
                                {
                                    last = pct;
                                    progress.Report(pct);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    static class PackFile
    {
        public static void Replace(string partial, string finalPath)
        {
            if (!File.Exists(partial))
                throw new IOException("The download did not finish.");
            if (!File.Exists(finalPath))
            {
                File.Move(partial, finalPath);
                return;
            }
            var backup = finalPath + ".previous";
            if (File.Exists(backup))
                File.Delete(backup);
            File.Move(finalPath, backup);
            try
            {
                File.Move(partial, finalPath);
                File.Delete(backup);
            }
            catch
            {
                if (!File.Exists(finalPath) && File.Exists(backup))
                    File.Move(backup, finalPath);
                throw;
            }
        }
    }

    static class GameStart
    {
        static readonly object Gate = new object();
        static DateTime Opened = DateTime.MinValue;

        [DllImport("user32.dll")]
        static extern bool AllowSetForegroundWindow(int processId);

        [DllImport("user32.dll")]
        static extern bool SetForegroundWindow(IntPtr hwnd);

        [DllImport("user32.dll")]
        static extern bool IsWindowVisible(IntPtr hwnd);

        [DllImport("user32.dll")]
        static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);

        [DllImport("user32.dll")]
        static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);

        [DllImport("user32.dll")]
        static extern bool EnumWindows(EnumProc callback, IntPtr param);

        delegate bool EnumProc(IntPtr hwnd, IntPtr param);

        struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        public static bool Open(string exe, string arguments, string directory)
        {
            lock (Gate)
            {
                if (Opened != DateTime.MinValue && (DateTime.Now - Opened).TotalSeconds < 3)
                    return true;
                Opened = DateTime.Now;
            }
            try
            {
                AllowSetForegroundWindow(-1);
                var info = new ProcessStartInfo();
                info.FileName = "explorer.exe";
                info.UseShellExecute = false;
                info.CreateNoWindow = true;
                if (string.IsNullOrEmpty(arguments))
                    info.Arguments = "\"" + exe + "\"";
                else
                {
                    var link = Path.Combine(Path.GetTempPath(), "ToontownLauncher.lnk");
                    WriteShortcut(link, exe, arguments, directory);
                    info.Arguments = "\"" + link + "\"";
                }
                Process.Start(info);
                return true;
            }
            catch (Exception)
            {
                lock (Gate)
                    Opened = DateTime.MinValue;
                return false;
            }
        }

        public static IntPtr FindGameWindow()
        {
            var pids = new List<int>();
            var processes = Process.GetProcessesByName("Toontown");
            foreach (var process in processes)
                pids.Add(process.Id);
            if (pids.Count == 0)
                return IntPtr.Zero;
            IntPtr best = IntPtr.Zero;
            var bestArea = 0;
            EnumWindows(delegate (IntPtr hwnd, IntPtr param)
            {
                uint windowPid;
                GetWindowThreadProcessId(hwnd, out windowPid);
                if (!pids.Contains((int)windowPid) || !IsWindowVisible(hwnd))
                    return true;
                RECT rect;
                if (!GetWindowRect(hwnd, out rect))
                    return true;
                var area = (rect.Right - rect.Left) * (rect.Bottom - rect.Top);
                if (area > bestArea)
                {
                    bestArea = area;
                    best = hwnd;
                }
                return true;
            }, IntPtr.Zero);
            return best;
        }

        public static void HandToGame(IntPtr gameWindow)
        {
            AllowSetForegroundWindow(-1);
            SetForegroundWindow(gameWindow);
        }

        static void WriteShortcut(string link, string exe, string arguments, string directory)
        {
            var shellType = Type.GetTypeFromProgID("WScript.Shell");
            var shell = Activator.CreateInstance(shellType);
            var shortcut = shellType.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { link });
            var type = shortcut.GetType();
            type.InvokeMember("TargetPath", BindingFlags.SetProperty, null, shortcut, new object[] { exe });
            type.InvokeMember("Arguments", BindingFlags.SetProperty, null, shortcut, new object[] { arguments });
            type.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, shortcut, new object[] { directory });
            type.InvokeMember("Save", BindingFlags.InvokeMethod, null, shortcut, new object[0]);
        }
    }
}
