using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace ToontownLauncher
{
    sealed class MainForm : Form
    {
        static readonly Color Ink = Color.FromArgb(84, 51, 20);
        static readonly Color InkSoft = Color.FromArgb(122, 82, 41);
        static readonly Color FieldBg = Color.FromArgb(255, 247, 224);
        static readonly Color FieldBorder = Color.FromArgb(140, 82, 20);
        static readonly Color FieldFocus = Color.FromArgb(217, 115, 20);
        static readonly Color ButtonText = Color.FromArgb(41, 26, 5);
        static readonly Color SkyFallback = Color.FromArgb(20, 89, 212);

        readonly string _baseDir;
        readonly string _gameDir;
        readonly string _configPath;
        readonly LauncherConfig _config;
        readonly Image _sky;
        readonly Image _logo;
        readonly Image _scroll;
        readonly Image _buttonUp;
        readonly Image _buttonDown;
        readonly Image _buttonHover;
        readonly Font _font16;
        readonly Font _font18;
        readonly Font _font22;
        readonly ScrollPanel _panel;
        readonly Label _status;
        readonly Label _addressLabel;
        readonly FieldBox _addressBox;
        readonly Label _portLabel;
        readonly FieldBox _portBox;
        readonly PillButton _solo;
        readonly PillButton _host;
        readonly PillButton _join;
        readonly PillButton _quit;
        readonly Label _hostBody;
        readonly PillButton _hostPlay;
        readonly PillButton _hostBack;
        readonly Control[] _menu;
        readonly Control[] _hostCard;
        bool _busy;
        bool _playLocal;
        bool _hosting;
        CancellationTokenSource _cancel;
        System.Windows.Forms.Timer _handOff;
        int _handOffTries;
        int _seenAt;
        static PrivateFontCollection _fonts;
        static GCHandle _fontPin;
        static byte[] _fontBytes;

        public MainForm()
        {
            _baseDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\', '/');
            _gameDir = Path.Combine(_baseDir, "game");
            _configPath = Path.Combine(_baseDir, "launcher.json");
            _config = LauncherConfig.Load(_configPath);
            _sky = LoadImage("sky.png");
            _logo = CropLogo(LoadImage("logo.png"));
            _scroll = LoadImage("scroll.png");
            _buttonUp = LoadImage("button_up.png");
            _buttonDown = LoadImage("button_down.png");
            _buttonHover = LoadImage("button_hover.png");
            var family = LoadFamily();
            _font16 = new Font(family, 16f, FontStyle.Regular, GraphicsUnit.Pixel);
            _font18 = new Font(family, 18f, FontStyle.Regular, GraphicsUnit.Pixel);
            _font22 = new Font(family, 22f, FontStyle.Regular, GraphicsUnit.Pixel);

            Text = "Toontown Launcher";
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            ClientSize = new Size(960, 960);
            BackColor = SkyFallback;
            DoubleBuffered = true;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);

            _panel = new ScrollPanel(_scroll);
            _panel.Parent = this;

            _status = MakeLabel(_font18, ContentAlignment.TopCenter);
            _status.Height = 72;
            _addressLabel = MakeLabel(_font16, ContentAlignment.MiddleLeft);
            _addressLabel.Text = "Address";
            _addressLabel.Height = 24;
            _addressBox = new FieldBox(_font18, Ink, InkSoft, FieldBg, FieldBorder, FieldFocus);
            _addressBox.Text = _config.Address;
            _addressBox.Placeholder = "192.168.1.20";
            _portLabel = MakeLabel(_font16, ContentAlignment.MiddleLeft);
            _portLabel.Text = "Port";
            _portLabel.Height = 24;
            _portBox = new FieldBox(_font18, Ink, InkSoft, FieldBg, FieldBorder, FieldFocus);
            _portBox.Text = _config.Port.ToString();
            _portBox.Placeholder = "4343";
            _solo = MakeButton("Single Player");
            _host = MakeButton("Host");
            _join = MakeButton("Join");
            _quit = MakeButton("Quit");
            _hostBody = MakeLabel(_font18, ContentAlignment.TopCenter);
            _hostBody.Height = 180;
            _hostPlay = MakeButton("Play");
            _hostBack = MakeButton("Back");

            _menu = new Control[] { _addressLabel, _addressBox, _portLabel, _portBox, _solo, _host, _join, _quit };
            _hostCard = new Control[] { _hostBody, _hostPlay, _hostBack };
            foreach (var control in _menu)
                control.Parent = _panel;
            foreach (var control in _hostCard)
            {
                control.Parent = _panel;
                control.Visible = false;
            }
            _status.Parent = _panel;

            _solo.Click += delegate { Play("solo"); };
            _host.Click += delegate { Play("host"); };
            _join.Click += delegate { Play("join"); };
            _quit.Click += delegate { Close(); };
            _hostPlay.Click += delegate { Launch("host"); };
            _hostBack.Click += delegate { ShowMenu(); };

            ClearPartials();
            ShowInstalled();
            LayoutUi();
        }

        Label MakeLabel(Font font, ContentAlignment align)
        {
            var label = new Label();
            label.Font = font;
            label.ForeColor = Ink;
            label.BackColor = Color.Transparent;
            label.TextAlign = align;
            label.AutoSize = false;
            return label;
        }

        PillButton MakeButton(string caption)
        {
            var button = new PillButton(_buttonUp, _buttonDown, _buttonHover, _font22, ButtonText);
            button.Text = caption;
            button.Height = 46;
            return button;
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            if (_sky == null)
            {
                e.Graphics.Clear(SkyFallback);
                return;
            }
            e.Graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
            e.Graphics.DrawImage(_sky, ClientRectangle);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            if (_logo == null)
                return;
            var top = _panel.Top - 230;
            var rect = new Rectangle((ClientSize.Width - 520) / 2, top, 520, 230);
            e.Graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
            e.Graphics.DrawImage(_logo, rect);
        }

        void LayoutUi()
        {
            var inner = 560 - 96;
            var y = 58;
            _status.SetBounds(48, y, inner, 78);
            y += 86;
            if (!_hosting)
            {
                _addressLabel.SetBounds(48, y, inner, 24);
                y += 26;
                _addressBox.SetBounds(48, y, inner, 40);
                y += 48;
                _portLabel.SetBounds(48, y, inner, 24);
                y += 26;
                _portBox.SetBounds(48, y, inner, 40);
                y += 50;
                y = PlaceButton(_solo, y, inner);
                y = PlaceButton(_host, y, inner);
                y = PlaceButton(_join, y, inner);
                y = PlaceButton(_quit, y, inner);
            }
            else
            {
                _hostBody.SetBounds(48, y, inner, 200);
                y += 208;
                y = PlaceButton(_hostPlay, y, inner);
                y = PlaceButton(_hostBack, y, inner);
            }
            y += 56;
            var panelHeight = y;
            var block = 230 + panelHeight;
            var top = Math.Max(12, (ClientSize.Height - block) / 2);
            _panel.SetBounds((ClientSize.Width - 560) / 2, top + 230, 560, panelHeight);
            Invalidate();
        }

        int PlaceButton(Control button, int y, int inner)
        {
            button.SetBounds(48, y, inner, 46);
            return y + 54;
        }

        void ShowMenu()
        {
            _hosting = false;
            foreach (var control in _hostCard)
                control.Visible = false;
            foreach (var control in _menu)
                control.Visible = true;
            ShowInstalled();
            LayoutUi();
        }

        void ShowHost()
        {
            var listed = "No local address was found. On this computer, use 127.0.0.1.";
            var lines = LanLines();
            if (lines.Length > 0)
                listed = string.Join("\n", lines);
            _hostBody.Text = "The game will open this computer on UDP port " + Port() + ".\n\nOther players type one of these addresses, and the same port.\n\n" + listed + "\n\nOn this same computer, the address is 127.0.0.1.";
            foreach (var control in _menu)
                control.Visible = false;
            foreach (var control in _hostCard)
                control.Visible = true;
            _hosting = true;
            _busy = false;
            SetBusy(false);
            LayoutUi();
        }

        void ShowInstalled()
        {
            if (!File.Exists(GameExe()))
            {
                _status.Text = "game/Toontown.exe was not found beside this launcher.\nPlay checks GitHub and downloads every .pck on the release.\nToontown.exe is left as it is.";
                return;
            }
            if (string.IsNullOrEmpty(_config.Release))
            {
                _status.Text = "Play checks GitHub for the latest release, then downloads each .pck when a newer one is available.";
                return;
            }
            _status.Text = "This copy is " + _config.Release + ". Play checks GitHub before the game starts.";
        }

        async void Play(string mode)
        {
            if (_busy)
                return;
            if (!FieldsOk(mode))
                return;
            SaveFields();
            if (_playLocal)
            {
                _playLocal = false;
                Continue(mode);
                return;
            }
            if (!File.Exists(GameExe()))
            {
                _status.Text = "game/Toontown.exe was not found. Play does not download or replace that file.";
                return;
            }
            _busy = true;
            SetBusy(true);
            if (_cancel != null)
                _cancel.Dispose();
            _cancel = new CancellationTokenSource();
            try
            {
                _status.Text = "Checking GitHub for a newer release...";
                var info = await ReleaseClient.GetLatestAsync(_cancel.Token);
                var needed = PacksToDownload(info);
                if (needed.Count == 0)
                {
                    _status.Text = "Up to date (" + info.Tag + ").";
                    Continue(mode);
                    return;
                }
                for (var i = 0; i < needed.Count; i++)
                {
                    var pack = needed[i];
                    var dest = Path.Combine(_gameDir, pack.Name);
                    var partial = dest + ".partial";
                    if (File.Exists(partial))
                        File.Delete(partial);
                    var label = pack.Name;
                    if (needed.Count > 1)
                        label = pack.Name + " (" + (i + 1) + " of " + needed.Count + ")";
                    var progress = new Progress<int>(delegate (int pct)
                    {
                        _status.Text = "Downloading " + label + "... " + pct + "%.";
                    });
                    await ReleaseClient.DownloadAsync(pack.Url, partial, pack.Name, progress, _cancel.Token);
                    PackFile.Replace(partial, dest);
                }
                _config.Release = info.Tag;
                _config.Save(_configPath);
                _status.Text = "Updated to " + info.Tag + ".";
                Continue(mode);
            }
            catch (OperationCanceledException)
            {
                _busy = false;
                SetBusy(false);
            }
            catch (Exception ex)
            {
                TryDeletePartial();
                Fail(Friendly(ex));
            }
        }

        void Continue(string mode)
        {
            if (mode == "host")
            {
                ShowHost();
                return;
            }
            Launch(mode);
        }

        void Launch(string mode)
        {
            var exe = GameExe();
            if (!File.Exists(exe))
            {
                Fail("game/Toontown.exe was not found. Play does not download or replace that file.");
                return;
            }
            if (!File.Exists(PackPath()))
            {
                Fail("game/Toontown.pck was not found.");
                return;
            }
            var arguments = "";
            if (mode == "host")
                arguments = "-- --host " + Port();
            else if (mode == "join")
                arguments = "-- --join " + QuoteArg(Address()) + " " + Port();
            if (!GameStart.Open(exe, arguments, _gameDir))
            {
                _busy = false;
                SetBusy(false);
                _status.Text = "The game did not start.";
                return;
            }
            _status.Text = "The game is open.";
            _busy = false;
            SetBusy(false);
            BeginHandOff();
        }

        void BeginHandOff()
        {
            _handOffTries = 0;
            _seenAt = 0;
            if (_handOff == null)
            {
                _handOff = new System.Windows.Forms.Timer();
                _handOff.Interval = 200;
                _handOff.Tick += delegate { OnHandOff(); };
            }
            _handOff.Start();
        }

        void OnHandOff()
        {
            _handOffTries++;
            var hwnd = GameStart.FindGameWindow();
            if (hwnd != IntPtr.Zero)
            {
                if (_seenAt == 0)
                    _seenAt = _handOffTries;
                if (_handOffTries - _seenAt < 5)
                    return;
                GameStart.HandToGame(hwnd);
                _handOff.Stop();
                Close();
                return;
            }
            if (_handOffTries >= 75)
                _handOff.Stop();
        }

        void Fail(string message)
        {
            _busy = false;
            SetBusy(false);
            if (File.Exists(GameExe()) && File.Exists(PackPath()))
            {
                _playLocal = true;
                _status.Text = message + " Click again to play this copy.";
                return;
            }
            _status.Text = message;
        }

        static string Friendly(Exception ex)
        {
            var web = ex as HttpRequestException;
            if (web != null)
                return "Could not reach GitHub.";
            if (ex is WebException)
                return "Could not reach GitHub.";
            if (ex.Message != null && ex.Message.Length > 0)
                return ex.Message;
            return "The download did not finish.";
        }

        bool FieldsOk(string mode)
        {
            var port = Port();
            if (port < 1 || port > 65535)
            {
                _status.Text = "Type a port from 1 to 65535.";
                return false;
            }
            if (mode == "join" && Address().Length == 0)
            {
                _status.Text = "Type the host computer's address.";
                return false;
            }
            return true;
        }

        void SaveFields()
        {
            _config.Address = Address();
            _config.Port = Port();
            try { _config.Save(_configPath); }
            catch (Exception) { }
        }

        string Address()
        {
            return _addressBox.Text.Trim();
        }

        int Port()
        {
            int port;
            if (!int.TryParse(_portBox.Text.Trim(), out port))
                return 0;
            return port;
        }

        void SetBusy(bool busy)
        {
            _solo.Enabled = !busy;
            _host.Enabled = !busy;
            _join.Enabled = !busy;
            _hostPlay.Enabled = !busy;
            _hostBack.Enabled = !busy;
        }

        string GameExe()
        {
            return Path.Combine(_gameDir, "Toontown.exe");
        }

        string PackPath()
        {
            return Path.Combine(_gameDir, "Toontown.pck");
        }

        System.Collections.Generic.List<ReleasePack> PacksToDownload(ReleaseInfo info)
        {
            var needed = new System.Collections.Generic.List<ReleasePack>();
            var sameRelease = _config.Release == info.Tag;
            foreach (var pack in info.Packs)
            {
                var dest = Path.Combine(_gameDir, pack.Name);
                if (!sameRelease || !File.Exists(dest))
                    needed.Add(pack);
            }
            return needed;
        }

        void ClearPartials()
        {
            if (!Directory.Exists(_gameDir))
                return;
            foreach (var partial in Directory.GetFiles(_gameDir, "*.partial"))
            {
                if (!partial.EndsWith(".pck.partial", StringComparison.OrdinalIgnoreCase))
                    continue;
                try { File.Delete(partial); }
                catch (Exception) { }
            }
        }

        void TryDeletePartial()
        {
            ClearPartials();
        }

        static string QuoteArg(string text)
        {
            if (text.IndexOf(' ') < 0 && text.IndexOf('"') < 0)
                return text;
            return "\"" + text.Replace("\"", "") + "\"";
        }

        static string[] LanLines()
        {
            var lines = new System.Collections.Generic.List<string>();
            foreach (var nic in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (nic.OperationalStatus != OperationalStatus.Up)
                    continue;
                foreach (var uni in nic.GetIPProperties().UnicastAddresses)
                {
                    if (uni.Address.AddressFamily != AddressFamily.InterNetwork)
                        continue;
                    var address = uni.Address.ToString();
                    if (address == "127.0.0.1" || address.StartsWith("169.254."))
                        continue;
                    if (!lines.Contains(address))
                        lines.Add(address);
                }
            }
            return lines.ToArray();
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (_cancel != null)
                _cancel.Cancel();
            if (_handOff != null)
                _handOff.Stop();
            base.OnFormClosing(e);
        }

        static Image LoadImage(string name)
        {
            var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(name);
            if (stream == null)
                return null;
            using (stream)
            using (var image = Image.FromStream(stream))
                return new Bitmap(image);
        }

        static Image CropLogo(Image source)
        {
            if (source == null)
                return null;
            var crop = new Rectangle(28, 86, 978, 782);
            if (crop.Right > source.Width || crop.Bottom > source.Height)
                return source;
            var bitmap = new Bitmap(crop.Width, crop.Height);
            using (var graphics = Graphics.FromImage(bitmap))
            {
                graphics.DrawImage(source, new Rectangle(0, 0, crop.Width, crop.Height), crop, GraphicsUnit.Pixel);
            }
            source.Dispose();
            return bitmap;
        }

        static FontFamily LoadFamily()
        {
            var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("ImpressBT.ttf");
            if (stream == null)
                return FontFamily.GenericSansSerif;
            using (stream)
            {
                _fontBytes = new byte[stream.Length];
                stream.Read(_fontBytes, 0, _fontBytes.Length);
            }
            _fontPin = GCHandle.Alloc(_fontBytes, GCHandleType.Pinned);
            _fonts = new PrivateFontCollection();
            _fonts.AddMemoryFont(_fontPin.AddrOfPinnedObject(), _fontBytes.Length);
            if (_fonts.Families.Length == 0)
                return FontFamily.GenericSansSerif;
            return _fonts.Families[0];
        }
    }

    sealed class ScrollPanel : Panel
    {
        readonly Image _scroll;
        Bitmap _slice;
        bool _building;

        public ScrollPanel(Image scroll)
        {
            _scroll = scroll;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            BackColor = Color.FromArgb(237, 230, 204);
        }

        protected override void OnSizeChanged(EventArgs e)
        {
            base.OnSizeChanged(e);
            if (_building || Width < 80 || Height < 80 || _scroll == null)
                return;
            _building = true;
            var next = NineSlice.Render(_scroll, new Size(Width, Height), 32, 32, 46, 52);
            var previous = _slice;
            _slice = next;
            BackgroundImage = _slice;
            if (previous != null)
                previous.Dispose();
            _building = false;
        }
    }

    sealed class FieldBox : Control
    {
        readonly TextBox _edit;
        readonly Color _border;
        readonly Color _focus;
        bool _focused;

        public string Placeholder;

        public override string Text
        {
            get { return _edit.Text; }
            set { _edit.Text = value; }
        }

        public FieldBox(Font font, Color ink, Color placeholder, Color background, Color border, Color focus)
        {
            _border = border;
            _focus = focus;
            Placeholder = "";
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            _edit = new TextBox();
            _edit.BorderStyle = BorderStyle.None;
            _edit.Font = font;
            _edit.ForeColor = ink;
            _edit.BackColor = background;
            _edit.Parent = this;
            _edit.GotFocus += delegate { _focused = true; Invalidate(); };
            _edit.LostFocus += delegate { _focused = false; Invalidate(); };
            BackColor = background;
            Height = 40;
        }

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, string lParam);

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            if (!string.IsNullOrEmpty(Placeholder))
                SendMessage(_edit.Handle, 0x1501, new IntPtr(1), Placeholder);
        }

        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);
            if (_edit == null)
                return;
            _edit.SetBounds(10, (Height - _edit.PreferredHeight) / 2, Math.Max(10, Width - 20), _edit.PreferredHeight);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            var rect = new Rectangle(1, 1, Width - 3, Height - 3);
            using (var pen = new Pen(_focused ? _focus : _border, 3f))
                NineSlice.DrawRound(e.Graphics, pen, rect, 8);
        }
    }

    sealed class PillButton : Control
    {
        readonly Image _up;
        readonly Image _down;
        readonly Image _hover;
        readonly Color _text;
        bool _pressed;
        bool _hovering;

        public PillButton(Image up, Image down, Image hover, Font font, Color text)
        {
            _up = up;
            _down = down;
            _hover = hover;
            _text = text;
            Font = font;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            SetStyle(ControlStyles.StandardClick, false);
            SetStyle(ControlStyles.StandardDoubleClick, false);
            Cursor = Cursors.Hand;
            Height = 46;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            var image = _up;
            if (Enabled && _pressed && _down != null)
                image = _down;
            else if (Enabled && _hovering && _hover != null)
                image = _hover;
            if (image != null)
            {
                if (Enabled)
                    NineSlice.Draw(e.Graphics, image, ClientRectangle, 18, 18, 10, 10);
                else
                    NineSlice.DrawFaded(e.Graphics, image, ClientRectangle, 18, 18, 10, 10);
            }
            var color = Enabled ? _text : Color.FromArgb(160, 71, 61, 41);
            TextRenderer.DrawText(e.Graphics, Text, Font, ClientRectangle, color, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
        }

        protected override void OnMouseEnter(EventArgs e)
        {
            _hovering = true;
            Invalidate();
            base.OnMouseEnter(e);
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            _hovering = false;
            _pressed = false;
            Invalidate();
            base.OnMouseLeave(e);
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Left)
            {
                _pressed = true;
                Invalidate();
            }
            base.OnMouseDown(e);
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            var fire = _pressed && e.Button == MouseButtons.Left && ClientRectangle.Contains(e.Location);
            _pressed = false;
            Invalidate();
            base.OnMouseUp(e);
            if (fire)
                OnClick(EventArgs.Empty);
        }
    }

    static class NineSlice
    {
        public static void Draw(Graphics graphics, Image image, Rectangle dest, int left, int right, int top, int bottom)
        {
            Draw(graphics, image, dest, left, right, top, bottom, null);
        }

        public static void DrawFaded(Graphics graphics, Image image, Rectangle dest, int left, int right, int top, int bottom)
        {
            using (var attributes = new ImageAttributes())
            {
                var matrix = new ColorMatrix();
                matrix.Matrix00 = 0.6f;
                matrix.Matrix11 = 0.6f;
                matrix.Matrix22 = 0.6f;
                matrix.Matrix33 = 1f;
                attributes.SetColorMatrix(matrix);
                Draw(graphics, image, dest, left, right, top, bottom, attributes);
            }
        }

        static void Draw(Graphics graphics, Image image, Rectangle dest, int left, int right, int top, int bottom, ImageAttributes attributes)
        {
            if (dest.Width <= 0 || dest.Height <= 0)
                return;
            var dl = Math.Min(left, dest.Width / 2);
            var dr = Math.Min(right, dest.Width - dl);
            var dt = Math.Min(top, dest.Height / 2);
            var db = Math.Min(bottom, dest.Height - dt);
            var sw = image.Width;
            var sh = image.Height;
            var sl = Math.Min(left, sw / 2);
            var sr = Math.Min(right, sw - sl);
            var st = Math.Min(top, sh / 2);
            var sb = Math.Min(bottom, sh - st);
            var cells = new int[,]
            {
                { 0, 0, sl, st, dest.X, dest.Y, dl, dt },
                { sl, 0, sw - sl - sr, st, dest.X + dl, dest.Y, dest.Width - dl - dr, dt },
                { sw - sr, 0, sr, st, dest.Right - dr, dest.Y, dr, dt },
                { 0, st, sl, sh - st - sb, dest.X, dest.Y + dt, dl, dest.Height - dt - db },
                { sl, st, sw - sl - sr, sh - st - sb, dest.X + dl, dest.Y + dt, dest.Width - dl - dr, dest.Height - dt - db },
                { sw - sr, st, sr, sh - st - sb, dest.Right - dr, dest.Y + dt, dr, dest.Height - dt - db },
                { 0, sh - sb, sl, sb, dest.X, dest.Bottom - db, dl, db },
                { sl, sh - sb, sw - sl - sr, sb, dest.X + dl, dest.Bottom - db, dest.Width - dl - dr, db },
                { sw - sr, sh - sb, sr, sb, dest.Right - dr, dest.Bottom - db, dr, db }
            };
            for (var i = 0; i < 9; i++)
            {
                if (cells[i, 2] <= 0 || cells[i, 3] <= 0 || cells[i, 6] <= 0 || cells[i, 7] <= 0)
                    continue;
                var src = new Rectangle(cells[i, 0], cells[i, 1], cells[i, 2], cells[i, 3]);
                var dst = new Rectangle(cells[i, 4], cells[i, 5], cells[i, 6], cells[i, 7]);
                if (attributes == null)
                    graphics.DrawImage(image, dst, src, GraphicsUnit.Pixel);
                else
                    graphics.DrawImage(image, dst, src.X, src.Y, src.Width, src.Height, GraphicsUnit.Pixel, attributes);
            }
        }

        public static Bitmap Render(Image image, Size size, int left, int right, int top, int bottom)
        {
            var bitmap = new Bitmap(Math.Max(1, size.Width), Math.Max(1, size.Height));
            using (var graphics = Graphics.FromImage(bitmap))
            {
                graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
                Draw(graphics, image, new Rectangle(0, 0, bitmap.Width, bitmap.Height), left, right, top, bottom);
            }
            return bitmap;
        }

        public static void DrawRound(Graphics graphics, Pen pen, Rectangle rect, int radius)
        {
            using (var path = Round(rect, radius))
                graphics.DrawPath(pen, path);
        }

        static GraphicsPath Round(Rectangle rect, int radius)
        {
            var path = new GraphicsPath();
            var d = radius * 2;
            path.AddArc(rect.X, rect.Y, d, d, 180, 90);
            path.AddArc(rect.Right - d, rect.Y, d, d, 270, 90);
            path.AddArc(rect.Right - d, rect.Bottom - d, d, d, 0, 90);
            path.AddArc(rect.X, rect.Bottom - d, d, d, 90, 90);
            path.CloseFigure();
            return path;
        }
    }
}
