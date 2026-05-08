function Convert-AllegroLinks {
    <#
    .NOTES
        Author: DanielBuczynski@gmail.com
        Release: 2026.05.08 16:00
        Version: 2026.05.08.02
        License: MIT
        This function is a part of the BUTCH PowerShell module.
        
    .LINK
        Latest version: https://github.com/dbuczynski/PowerShell
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)]
        [string[]]$Links
    )
    begin {
        $output = @()
    }
    process {
        # Każdy element może zawierać wiele linków oddzielonych spacją lub tabulatorem
        $expanded = $Links | ForEach-Object {
            $_.Split([char[]]@(' ', "`t"), [System.StringSplitOptions]::RemoveEmptyEntries)
        }

        foreach ($link in $expanded) {
            $split = $link.ToString().Split('=')
            $url = "http://allegro.pl/show_item.php?item={0}" -f $split[-1]
            $Output += $url
            Write-Information $url
        }
    }
    end {
        return $output
    }
}


