using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Windows.Forms;

internal static class Program
{
    private const string AppUrl = "http://127.0.0.1:8765/prompt-log.html";
    private static Mutex instanceMutex;
    internal static bool SuppressInitialBrowser { get; private set; }

    [STAThread]
    private static void Main()
    {
        SuppressInitialBrowser = Array.IndexOf(Environment.GetCommandLineArgs(), "--no-browser") >= 0;
        bool createdNew;
        instanceMutex = new Mutex(true, "Local\\PromptLog.Application", out createdNew);
        if (!createdNew)
        {
            OpenBrowser();
            return;
        }

        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        try
        {
            Application.Run(new PromptLogContext());
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                "Prompt Log를 시작하지 못했습니다.\n\n" + ex.Message +
                "\n\n포트 8765를 사용하는 다른 프로그램이 있는지 확인해주세요.",
                "Prompt Log 시작 오류",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
        finally
        {
            instanceMutex.ReleaseMutex();
            instanceMutex.Dispose();
        }
    }

    internal static void OpenBrowser()
    {
        Process.Start(new ProcessStartInfo(AppUrl) { UseShellExecute = true });
    }
}

internal sealed class PromptLogContext : ApplicationContext
{
    private readonly NotifyIcon trayIcon;
    private readonly LocalServer server;

    internal PromptLogContext()
    {
        server = new LocalServer(8765, LoadEmbeddedHtml());
        server.Start();

        var menu = new ContextMenuStrip();
        menu.Items.Add("Prompt Log 열기", null, delegate { Program.OpenBrowser(); });
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("종료", null, delegate { ExitThread(); });

        trayIcon = new NotifyIcon
        {
            Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath) ?? SystemIcons.Application,
            Text = "Prompt Log",
            ContextMenuStrip = menu,
            Visible = true
        };
        trayIcon.DoubleClick += delegate { Program.OpenBrowser(); };
        trayIcon.ShowBalloonTip(
            2500,
            "Prompt Log가 실행 중입니다",
            "종료하려면 작업 표시줄 알림 영역의 아이콘을 오른쪽 클릭하세요.",
            ToolTipIcon.Info);

        if (!Program.SuppressInitialBrowser) Program.OpenBrowser();
    }

    protected override void ExitThreadCore()
    {
        trayIcon.Visible = false;
        trayIcon.Dispose();
        server.Dispose();
        base.ExitThreadCore();
    }

    private static byte[] LoadEmbeddedHtml()
    {
        using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("PromptLog.Html"))
        {
            if (stream == null) throw new InvalidOperationException("내장된 prompt-log.html을 찾을 수 없습니다.");
            using (var memory = new MemoryStream())
            {
                stream.CopyTo(memory);
                return memory.ToArray();
            }
        }
    }
}

internal sealed class LocalServer : IDisposable
{
    private readonly int port;
    private readonly byte[] html;
    private TcpListener listener;
    private Thread thread;
    private volatile bool running;

    internal LocalServer(int port, byte[] html)
    {
        this.port = port;
        this.html = html;
    }

    internal void Start()
    {
        listener = new TcpListener(IPAddress.Loopback, port);
        listener.Start();
        running = true;
        thread = new Thread(ListenLoop) { IsBackground = true, Name = "PromptLog local server" };
        thread.Start();
    }

    private void ListenLoop()
    {
        while (running)
        {
            try
            {
                TcpClient client = listener.AcceptTcpClient();
                ThreadPool.QueueUserWorkItem(delegate { Serve(client); });
            }
            catch (SocketException)
            {
                if (running) throw;
            }
            catch (ObjectDisposedException) { }
        }
    }

    private void Serve(TcpClient client)
    {
        using (client)
        using (NetworkStream stream = client.GetStream())
        using (var reader = new StreamReader(stream, Encoding.ASCII, false, 4096, true))
        {
            client.ReceiveTimeout = 5000;
            client.SendTimeout = 5000;

            string requestLine = reader.ReadLine();
            if (String.IsNullOrEmpty(requestLine)) return;
            string[] parts = requestLine.Split(' ');
            string method = parts.Length > 0 ? parts[0] : "";
            string path = parts.Length > 1 ? parts[1].Split('?')[0] : "";

            string line;
            do { line = reader.ReadLine(); } while (!String.IsNullOrEmpty(line));

            bool isHead = method == "HEAD";
            bool allowedMethod = method == "GET" || isHead;
            bool appPath = path == "/" || path == "/prompt-log.html";

            if (allowedMethod && appPath)
                WriteResponse(stream, "200 OK", "text/html; charset=utf-8", html, isHead);
            else if (!allowedMethod)
                WriteResponse(stream, "405 Method Not Allowed", "text/plain; charset=utf-8", Encoding.UTF8.GetBytes("Method Not Allowed"), isHead);
            else
                WriteResponse(stream, "404 Not Found", "text/plain; charset=utf-8", Encoding.UTF8.GetBytes("Not Found"), isHead);
        }
    }

    private static void WriteResponse(NetworkStream stream, string status, string type, byte[] body, bool headersOnly)
    {
        string headers = "HTTP/1.1 " + status + "\r\n" +
            "Content-Type: " + type + "\r\n" +
            "Content-Length: " + body.Length + "\r\n" +
            "Cache-Control: no-store\r\n" +
            "X-Content-Type-Options: nosniff\r\n" +
            "Referrer-Policy: no-referrer\r\n" +
            "Connection: close\r\n\r\n";
        byte[] headerBytes = Encoding.ASCII.GetBytes(headers);
        stream.Write(headerBytes, 0, headerBytes.Length);
        if (!headersOnly) stream.Write(body, 0, body.Length);
    }

    public void Dispose()
    {
        running = false;
        if (listener != null) listener.Stop();
        if (thread != null && thread.IsAlive) thread.Join(1000);
    }
}
