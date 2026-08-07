namespace Thrustline.Bridge.SimConnect;

public enum SimConnectLibraryOrigin
{
    None,
    Explicit,
    Application,
    SdkInstallation,
}

/// <summary>
/// Résultat de la sonde : l'origine retenue et le chemin absolu de la
/// bibliothèque, ou <see cref="Unavailable"/> quand aucune source digne de
/// confiance n'en possède une. Le chemin ne quitte jamais le processus :
/// santé et diagnostics ne publient que l'origine.
/// </summary>
public sealed record SimConnectLibraryLocation(
    SimConnectLibraryOrigin Origin,
    string? LibraryPath)
{
    public static SimConnectLibraryLocation Unavailable { get; } =
        new(SimConnectLibraryOrigin.None, null);
}

/// <summary>
/// Localise la bibliothèque cliente SimConnect dans une liste ordonnée et
/// fermée de sources : le chemin explicite de la ligne de commande, le
/// répertoire de l'application, puis l'installation du SDK telle que déclarée
/// par le système. Jamais le <c>PATH</c>, jamais le répertoire courant, jamais
/// un balayage de disque : une copie présente ailleurs n'est pas chargée.
/// </summary>
public static class SimConnectLibraryLocator
{
    public const string LibraryFileName = "SimConnect.dll";
    public const int MaximumPathLength = 260;

    // Le SDK MSFS déclare son installation par variable d'environnement ;
    // la déclaration 2024 prime, et une valeur pendante (répertoire disparu)
    // est ignorée au profit de la déclaration suivante.
    private static readonly string[] SdkEnvironmentVariables = ["MSFS2024_SDK", "MSFS_SDK"];
    private static readonly string SdkLibraryRelativePath =
        Path.Combine("SimConnect SDK", "lib", LibraryFileName);

    public static SimConnectLibraryLocation Locate(
        string? explicitPath,
        Func<string, string?>? environment = null,
        string? applicationDirectory = null)
    {
        // 1. Chemin explicite : s'il est fourni, il est la seule source
        //    consultée — un chemin invalide ne retombe jamais sur une autre
        //    source, pour qu'une faute de frappe ne charge pas autre chose
        //    que ce qui a été demandé.
        if (explicitPath is not null)
        {
            return IsTrustedLibraryFile(explicitPath)
                ? new(SimConnectLibraryOrigin.Explicit, Path.GetFullPath(explicitPath))
                : SimConnectLibraryLocation.Unavailable;
        }

        // 2. Le répertoire de l'application.
        var applicationCandidate = Path.Combine(
            applicationDirectory ?? AppContext.BaseDirectory,
            LibraryFileName);
        if (IsTrustedLibraryFile(applicationCandidate))
        {
            return new(
                SimConnectLibraryOrigin.Application,
                Path.GetFullPath(applicationCandidate));
        }

        // 3. L'installation du SDK déclarée par le système.
        var readVariable = environment ?? Environment.GetEnvironmentVariable;
        foreach (var variable in SdkEnvironmentVariables)
        {
            var declaredRoot = readVariable(variable);
            if (string.IsNullOrWhiteSpace(declaredRoot)
                || declaredRoot.Length > MaximumPathLength
                || declaredRoot.IndexOfAny(Path.GetInvalidPathChars()) >= 0
                || !Path.IsPathFullyQualified(declaredRoot))
            {
                continue;
            }

            var candidate = Path.Combine(declaredRoot, SdkLibraryRelativePath);
            if (IsTrustedLibraryFile(candidate))
            {
                return new(
                    SimConnectLibraryOrigin.SdkInstallation,
                    Path.GetFullPath(candidate));
            }
        }

        return SimConnectLibraryLocation.Unavailable;
    }

    /// <summary>
    /// Forme acceptable pour un chemin explicite, vérifiable sans toucher le
    /// disque : absolu, borné, sans caractère invalide, et nommant exactement
    /// la bibliothèque cliente — jamais un binaire arbitraire.
    /// </summary>
    public static bool HasTrustedShape(string? value) =>
        !string.IsNullOrWhiteSpace(value)
        && value.Length <= MaximumPathLength
        && value.IndexOfAny(Path.GetInvalidPathChars()) < 0
        && Path.IsPathFullyQualified(value)
        && string.Equals(
            Path.GetFileName(value),
            LibraryFileName,
            StringComparison.OrdinalIgnoreCase);

    private static bool IsTrustedLibraryFile(string path)
    {
        if (!HasTrustedShape(path))
        {
            return false;
        }

        var fullPath = Path.GetFullPath(path);
        if (!File.Exists(fullPath))
        {
            return false;
        }

        // Un fichier réel, pas un point de réanalyse : un lien symbolique
        // détournerait la provenance consignée.
        var attributes = File.GetAttributes(fullPath);
        return (attributes & FileAttributes.ReparsePoint) == 0;
    }
}
