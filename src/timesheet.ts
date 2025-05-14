import * as cp from "child_process";
import * as path from "path";
import * as fs from "fs";
import * as os from "os";

export async function generateTimesheet(
  repoPath: string,
  dayOffset: number,
  extensionPath: string,
  forceFetch?: boolean
): Promise<string> {
  // Create a temporary script file
  const scriptContent = getScriptContent(extensionPath);
  const tempScriptPath = path.join(os.tmpdir(), `git_commits_${Date.now()}.sh`);

  try {
    // Write script to temp file
    fs.writeFileSync(tempScriptPath, scriptContent, { mode: 0o755 });

    // Build the command with optional -f
    let cmd = `bash "${tempScriptPath}" -r "${repoPath}" -d ${dayOffset}`;
    if (forceFetch) {
      cmd += " -f";
    }
    const result = cp.execSync(cmd, {
      encoding: "utf8",
      maxBuffer: 1024 * 1024 * 5, // 5MB buffer
    });
    return result;
  } finally {
    // Clean up temp file
    try {
      fs.unlinkSync(tempScriptPath);
    } catch (error) {
      console.error("Failed to delete temporary script file:", error);
    }
  }
}

function getScriptContent(extensionPath: string): string {
  const scriptPath = path.join(extensionPath, "git-commits.sh");
  try {
    return fs.readFileSync(scriptPath, "utf8");
  } catch (error) {
    console.error(`Failed to read script file at ${scriptPath}:`, error);
    throw new Error(
      `Could not load the timesheet script. Please ensure 'git-commits.sh' exists at ${scriptPath}.`
    );
  }
}
