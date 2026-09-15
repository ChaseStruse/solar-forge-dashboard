import QtQuick
import Quickshell.Io

// One bounded GitHub sync feeds the action center, briefing, and timeline.
QtObject {
    id: root
    property var repositories: []
    property var actionItems: []
    property string viewerLogin: ""
    property string status: "GITHUB NOT YET LOADED"
    property string refreshedAt: ""
    property bool timedOut: false
    readonly property bool loading: process.running
    readonly property int actionableCount: actionItems.length
    readonly property var visibleItems: actionItems.slice(0, 4)

    function refresh() {
        if (loading)
            return;
        timedOut = false;
        status = "SYNCING ACTION SIGNAL…";
        process.running = true;
        deadline.restart();
    }

    function array(value) {
        return Array.isArray(value) ? value : [];
    }

    function repositoryName(row) {
        return row && row.repository && typeof row.repository.nameWithOwner === "string"
            ? row.repository.nameWithOwner : "UNKNOWN REPOSITORY";
    }

    function checkState(pullRequest) {
        var commits = pullRequest && pullRequest.commits ? array(pullRequest.commits.nodes) : [];
        if (!commits.length || !commits[0].commit || !commits[0].commit.statusCheckRollup)
            return "UNKNOWN";
        return String(commits[0].commit.statusCheckRollup.state || "UNKNOWN").toUpperCase();
    }

    function notificationUrl(notification) {
        var apiUrl = notification && notification.subject ? String(notification.subject.url || "") : "";
        var match = apiUrl.match(/^https:\/\/api\.github\.com\/repos\/([^/]+)\/([^/]+)\/(issues|pulls|commits)\/([^/]+)$/);
        if (match)
            return "https://github.com/" + match[1] + "/" + match[2] + "/"
                + (match[3] === "pulls" ? "pull" : match[3] === "issues" ? "issues" : "commit")
                + "/" + match[4];
        return notification && notification.repository ? String(notification.repository.html_url || "") : "";
    }

    function item(kind, title, repo, url, updatedAt, priority, detail, tone) {
        return {
            kind: kind,
            title: String(title || "Untitled"),
            repository: String(repo || "UNKNOWN REPOSITORY"),
            url: String(url || ""),
            updatedAt: String(updatedAt || ""),
            priority: priority,
            detail: String(detail || ""),
            tone: tone || "accent"
        };
    }

    function consume(raw) {
        try {
            var payload = JSON.parse(String(raw || ""));
            if (!payload || typeof payload !== "object" || !payload.viewer)
                throw new Error("Expected GitHub intelligence object");

            viewerLogin = String(payload.viewer.login || "");
            repositories = array(payload.viewer.repositories && payload.viewer.repositories.nodes)
                .filter(function(row) { return row && typeof row.name === "string"; }).slice(0, 4);

            var candidates = [];
            array(payload.viewer.pullRequests && payload.viewer.pullRequests.nodes).forEach(function(pr) {
                if (!pr || !pr.url)
                    return;
                var checks = root.checkState(pr);
                if (checks === "FAILURE" || checks === "ERROR")
                    candidates.push(root.item("CI FAILED", pr.title, root.repositoryName(pr), pr.url,
                        pr.updatedAt, 0, "Your pull request has failing checks", "urgent"));
                else if (String(pr.reviewDecision || "") === "CHANGES_REQUESTED"
                        || String(pr.mergeable || "") === "CONFLICTING")
                    candidates.push(root.item("PR BLOCKED", pr.title, root.repositoryName(pr), pr.url,
                        pr.updatedAt, 3, "Changes or conflict resolution required", "urgent"));
                else if (!pr.isDraft && String(pr.reviewDecision || "") === "APPROVED"
                        && String(pr.mergeable || "") === "MERGEABLE"
                        && (checks === "SUCCESS" || checks === "UNKNOWN"))
                    candidates.push(root.item("MERGE READY", pr.title, root.repositoryName(pr), pr.url,
                        pr.updatedAt, 2, "Approved and ready to merge", "autonomous"));
            });

            array(payload.reviewRequests).forEach(function(pr) {
                if (pr && pr.url)
                    candidates.push(root.item("REVIEW REQUEST", pr.title, root.repositoryName(pr), pr.url,
                        pr.updatedAt, 1, "Your review is requested", "accent"));
            });

            array(payload.notifications).forEach(function(notification) {
                if (!notification || !notification.unread || !notification.subject)
                    return;
                var reason = String(notification.reason || "");
                if (["mention", "team_mention", "review_requested", "assign"].indexOf(reason) === -1)
                    return;
                var repo = notification.repository ? notification.repository.full_name : "UNKNOWN REPOSITORY";
                candidates.push(root.item(reason === "review_requested" ? "REVIEW REQUEST" : "MENTION",
                    notification.subject.title, repo, root.notificationUrl(notification), notification.updated_at,
                    reason === "review_requested" ? 1 : 3,
                    reason === "assign" ? "GitHub assigned this to you" : "Unread GitHub notification", "accent"));
            });

            array(payload.assignedIssues).forEach(function(issue) {
                if (issue && issue.url)
                    candidates.push(root.item("ISSUE ASSIGNED", issue.title, root.repositoryName(issue), issue.url,
                        issue.updatedAt, 4, "Open issue assigned to you", "accent"));
            });

            var byUrl = {};
            candidates.forEach(function(candidate) {
                if (!candidate.url || !byUrl[candidate.url] || candidate.priority < byUrl[candidate.url].priority)
                    byUrl[candidate.url] = candidate;
            });
            var normalized = [];
            for (var url in byUrl)
                normalized.push(byUrl[url]);
            normalized.sort(function(left, right) {
                if (left.priority !== right.priority)
                    return left.priority - right.priority;
                return new Date(right.updatedAt).getTime() - new Date(left.updatedAt).getTime();
            });
            actionItems = normalized.slice(0, 20);
            status = actionItems.length
                ? actionItems.length + (actionItems.length === 1 ? " ITEM NEEDS ATTENTION" : " ITEMS NEED ATTENTION")
                : "INBOX CLEAR";
            refreshedAt = Qt.formatTime(new Date(), "HH:mm");
            return true;
        } catch (failure) {
            repositories = [];
            actionItems = [];
            status = "GITHUB RESPONSE UNREADABLE";
            console.warn("Solar Forge GitHub response error:", failure);
            return false;
        }
    }

    readonly property Timer deadline: Timer {
        interval: 15000
        onTriggered: {
            root.timedOut = true;
            process.running = false;
            root.status = "GITHUB REQUEST TIMED OUT — REOPEN TO RETRY";
        }
    }

    readonly property Process process: Process {
        command: ["bash", Qt.resolvedUrl("scripts/github-intelligence.sh").toString().replace(/^file:\/\//, "")]
        environment: ({ GH_PROMPT_DISABLED: "1" })
        stdout: StdioCollector { id: output; waitForEnd: true }
        onExited: function(exitCode) {
            deadline.stop();
            if (root.timedOut)
                return;
            if (exitCode !== 0) {
                root.repositories = [];
                root.actionItems = [];
                root.status = "GITHUB CLI UNAVAILABLE — CHECK gh auth status";
            } else
                root.consume(output.text);
        }
    }
}
