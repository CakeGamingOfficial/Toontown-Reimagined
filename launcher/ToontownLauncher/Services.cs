using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
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
        public string WindowMode;
        public int Width;
        public int Height;

        public LauncherConfig()
        {
            Address = "";
            Port = 4343;
            Release = "";
            WindowMode = "windowed";
            Width = 0;
            Height = 0;
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
                if (root.ContainsKey("window") && root["window"] != null)
                {
                    var mode = root["window"].ToString();
                    if (mode == "windowed" || mode == "borderless" || mode == "fullscreen")
                        config.WindowMode = mode;
                }
                if (root.ContainsKey("width") && root["width"] != null)
                    config.Width = Convert.ToInt32(root["width"]);
                if (root.ContainsKey("height") && root["height"] != null)
                    config.Height = Convert.ToInt32(root["height"]);
            }
            catch (Exception)
            {
            }
            if (config.Port < 1 || config.Port > 65535)
                config.Port = 4343;
            if (config.WindowMode != "windowed" && config.WindowMode != "borderless" && config.WindowMode != "fullscreen")
                config.WindowMode = "windowed";
            if (config.Width < 640 || config.Height < 480)
            {
                config.Width = 0;
                config.Height = 0;
            }
            return config;
        }

        public void Save(string path)
        {
            var root = new Dictionary<string, object>();
            root["address"] = Address ?? "";
            root["port"] = Port;
            root["release"] = Release ?? "";
            root["window"] = WindowMode ?? "windowed";
            root["width"] = Width;
            root["height"] = Height;
            var serializer = new JavaScriptSerializer();
            File.WriteAllText(path, serializer.Serialize(root));
        }
    }

    static class DisplayFile
    {
        public static string PathForGame()
        {
            return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Godot", "app_userdata", "Toontown-Reimagined", "display.cfg");
        }

        public static void ReadInto(LauncherConfig config)
        {
            var path = PathForGame();
            if (!File.Exists(path))
                return;
            try
            {
                var lines = File.ReadAllLines(path);
                var mode = config.WindowMode;
                var width = config.Width;
                var height = config.Height;
                foreach (var raw in lines)
                {
                    string value;
                    if (Take(raw, "mode", out value))
                    {
                        if (value == "windowed" || value == "borderless" || value == "fullscreen")
                            mode = value;
                    }
                    else if (Take(raw, "width", out value))
                    {
                        int parsed;
                        if (int.TryParse(value, out parsed) && parsed >= 0)
                            width = parsed;
                    }
                    else if (Take(raw, "height", out value))
                    {
                        int parsed;
                        if (int.TryParse(value, out parsed) && parsed >= 0)
                            height = parsed;
                    }
                }
                config.WindowMode = mode;
                if (width < 640 || height < 480)
                {
                    config.Width = 0;
                    config.Height = 0;
                }
                else
                {
                    config.Width = width;
                    config.Height = height;
                }
            }
            catch (Exception)
            {
            }
        }

        public static void Write(LauncherConfig config)
        {
            var path = PathForGame();
            var vsync = "true";
            var extra = new List<string>();
            if (File.Exists(path))
            {
                var lines = File.ReadAllLines(path);
                foreach (var raw in lines)
                {
                    string value;
                    if (Take(raw, "vsync", out value))
                        vsync = value == "false" ? "false" : "true";
                    else if (Take(raw, "mode", out value) || Take(raw, "fullscreen", out value) || Take(raw, "width", out value) || Take(raw, "height", out value))
                        continue;
                    else if (raw.Trim().Length == 0 || raw.Trim().StartsWith("[") || raw.Trim().StartsWith(";"))
                        continue;
                    else
                        extra.Add(raw.Trim());
                }
            }
            var mode = config.WindowMode;
            if (mode != "windowed" && mode != "borderless" && mode != "fullscreen")
                mode = "windowed";
            var width = config.Width;
            var height = config.Height;
            if (width < 640 || height < 480)
            {
                width = 0;
                height = 0;
            }
            var text = new StringBuilder();
            text.Append("[display]\n\n");
            text.Append("mode=\"");
            text.Append(mode);
            text.Append("\"\nfullscreen=");
            text.Append(mode == "windowed" ? "false" : "true");
            text.Append("\nvsync=");
            text.Append(vsync);
            text.Append("\nwidth=");
            text.Append(width);
            text.Append("\nheight=");
            text.Append(height);
            text.Append("\n");
            foreach (var line in extra)
            {
                text.Append(line);
                text.Append("\n");
            }
            var dir = Path.GetDirectoryName(path);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                Directory.CreateDirectory(dir);
            File.WriteAllText(path, text.ToString());
        }

        static bool Take(string raw, string key, out string value)
        {
            value = "";
            var line = raw.Trim();
            if (!line.StartsWith(key))
                return false;
            var rest = line.Substring(key.Length).Trim();
            if (!rest.StartsWith("="))
                return false;
            rest = rest.Substring(1).Trim();
            if (rest.Length >= 2 && rest[0] == '"' && rest[rest.Length - 1] == '"')
                rest = rest.Substring(1, rest.Length - 2);
            value = rest;
            return true;
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
        public string Name;
        public string Page;
        public string Body;
        public List<ReleasePack> Packs;

        public ReleaseInfo()
        {
            Packs = new List<ReleasePack>();
        }
    }

    static class ReleaseClient
    {
        const string ReleasesUrl = "https://api.github.com/repos/CakeGamingOfficial/Toontown-Reimagined/releases?per_page=20";

        public static async Task<ReleaseInfo> GetLatestAsync(CancellationToken cancel)
        {
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            using (var http = new HttpClient())
            {
                http.Timeout = TimeSpan.FromSeconds(30);
                var request = new HttpRequestMessage(HttpMethod.Get, ReleasesUrl);
                request.Headers.TryAddWithoutValidation("User-Agent", "ToontownLauncher");
                request.Headers.TryAddWithoutValidation("Accept", "application/vnd.github+json");
                using (var response = await http.SendAsync(request, cancel))
                {
                    if (response.StatusCode == HttpStatusCode.NotFound)
                        throw new InvalidOperationException("GitHub has no release yet.");
                    if (!response.IsSuccessStatusCode)
                        throw new InvalidOperationException("GitHub returned an error (" + (int)response.StatusCode + ").");
                    var json = await response.Content.ReadAsStringAsync();
                    return ParseList(json);
                }
            }
        }

        static ReleaseInfo ParseList(string json)
        {
            var serializer = new JavaScriptSerializer();
            serializer.MaxJsonLength = int.MaxValue;
            var list = serializer.DeserializeObject(json) as IList;
            if (list == null || list.Count == 0)
                throw new InvalidOperationException("GitHub has no release yet.");
            Dictionary<string, object> newest = null;
            var newestAt = DateTime.MinValue;
            foreach (var item in list)
            {
                var row = item as Dictionary<string, object>;
                if (row == null || IsTrue(row, "draft"))
                    continue;
                var published = PublishedAt(row);
                if (newest == null || published > newestAt)
                {
                    newest = row;
                    newestAt = published;
                }
            }
            if (newest == null)
                throw new InvalidOperationException("GitHub has no release yet.");
            return ParseRelease(newest);
        }

        static bool IsTrue(Dictionary<string, object> root, string key)
        {
            if (!root.ContainsKey(key) || root[key] == null)
                return false;
            if (root[key] is bool)
                return (bool)root[key];
            return string.Equals(root[key].ToString(), "true", StringComparison.OrdinalIgnoreCase);
        }

        static DateTime PublishedAt(Dictionary<string, object> root)
        {
            if (!root.ContainsKey("published_at") || root["published_at"] == null)
                return DateTime.MinValue;
            DateTime published;
            if (!DateTime.TryParse(root["published_at"].ToString(), CultureInfo.InvariantCulture, DateTimeStyles.AdjustToUniversal | DateTimeStyles.AssumeUniversal, out published))
                return DateTime.MinValue;
            return published;
        }

        static ReleaseInfo ParseRelease(Dictionary<string, object> root)
        {
            if (root == null || !root.ContainsKey("tag_name") || root["tag_name"] == null)
                throw new InvalidOperationException("GitHub did not return a release.");
            var info = new ReleaseInfo();
            info.Tag = root["tag_name"].ToString().Trim();
            if (info.Tag.Length == 0)
                throw new InvalidOperationException("GitHub did not return a release.");
            if (root.ContainsKey("name") && root["name"] != null)
                info.Name = root["name"].ToString().Trim();
            if (root.ContainsKey("html_url") && root["html_url"] != null)
                info.Page = root["html_url"].ToString().Trim();
            if (root.ContainsKey("body") && root["body"] != null)
                info.Body = root["body"].ToString().Trim();
            var assets = root.ContainsKey("assets") ? root["assets"] as IList : null;
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

        public static int WindowProcessId(IntPtr hwnd)
        {
            uint processId;
            GetWindowThreadProcessId(hwnd, out processId);
            return (int)processId;
        }

        public static void ReopenWhenGameExits(int gamePid, string launcherExe)
        {
            if (gamePid <= 0 || string.IsNullOrEmpty(launcherExe))
                return;
            var script = "Wait-Process -Id " + gamePid + " -ErrorAction SilentlyContinue; Start-Process -FilePath '" + launcherExe.Replace("'", "''") + "'";
            var encoded = Convert.ToBase64String(Encoding.Unicode.GetBytes(script));
            var info = new ProcessStartInfo();
            info.FileName = "powershell.exe";
            info.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand " + encoded;
            info.UseShellExecute = false;
            info.CreateNoWindow = true;
            Process.Start(info);
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
