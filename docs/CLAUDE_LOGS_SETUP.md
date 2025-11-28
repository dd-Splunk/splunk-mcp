# Claude Logs Onboarding Documentation Update

## Overview

Documentation has been updated to fully document the Claude logs
onboarding feature that captures Claude Desktop logs into a dedicated
`claude_logs` index in Splunk.

## Changes Made

### 1. **QUICK_START.md**

- Added Claude logs explanation after Step 5 (Verify It Works)
- Updated "Next Steps" to prioritize querying Claude logs as first action
- Added simple search query example: `index=claude_logs`

### 2. **INSTALLATION.md**

- Added **Step 9: Monitor Claude Logs** section
- Documents automatic log indexing in `claude_logs` index
- Explains requirements and setup details:
  - Claude logs location: `~/Library/Logs/Claude/`
  - Automatic mounting in compose.yml
  - Auto-creation of index during initialization
  - Immediate log ingestion after Splunk is ready

### 3. **ARCHITECTURE.md**

- Updated "Data Persistence" section with Claude logs bind mount
- Added new **Section 4: Claude Logs Index** with details:
  - Index name: `claude_logs`
  - Data source: `~/Library/Logs/Claude/` (macOS)
  - Purpose: Capture Claude Desktop activity and errors
  - Automatic monitoring via Splunk input monitor
  - Searchability details
- Renumbered subsequent sections (Network is now Section 5)

### 4. **API_REFERENCE.md**

- Added **Claude Logs Index** section before debugging
- Provides practical search examples:
  - Query all Claude logs
  - Search by log level (ERROR)
  - Search by time range (last 1 hour)
  - Get index statistics via REST API

### 5. **TROUBLESHOOTING.md**

- Added **Claude Logs Debugging** section with 2 common issues:
  1. **No Claude logs in Splunk**
     - Checks: directory existence, mount point, index creation, monitor config
     - Solution: manual setup script re-run
  2. **Claude logs stopped being indexed**
     - Checks: monitor status, Claude app running, Splunk restart
     - Debugging tips

### 6. **DEVELOPER_GUIDE.md**

- Expanded "Extending the System" section
- Added **Add Custom Log Index** subsection:
  - Shows how to monitor additional log sources
  - Provides compose.yml example
  - Shows setup-splunk-user.sh modification pattern
- Kept "Add Additional Users" section

### 7. **README.md**

- Updated Access Information table
- Added Claude Logs entry: `Index: claude_logs - Automatically indexed`

## Technical Implementation (Already in Place)

The setup script (`setup-splunk-user.sh`) already implements:

1. **Index Creation**:

   ```bash
   curl -X POST "${SPLUNK_URL}/services/data/indexes" \
     -d "name=claude_logs" \
     -d "homePath=..." -d "coldPath=..." -d "thawedPath=..."
   ```

2. **Monitor Input**:

   ```bash
   curl -X POST "${SPLUNK_URL}/services/data/inputs/monitor/" \
     -d "name=/var/log/claude_logs" \
     -d "index=claude_logs"
   ```

3. **Volume Mount** (compose.yml):

   ```yaml
   volumes:
     - ${HOME}/Library/Logs/Claude:/var/log/claude_logs:rw
   ```

## User Workflows Documented

### Basic: View Claude Logs

1. Start Splunk: `make up`
2. Open Splunk Web UI: <https://localhost:8000>
3. Navigate to Search & Reporting
4. Search: `index=claude_logs`

### Advanced: Filter by Log Level

```spl
index=claude_logs log_level=ERROR | stats count by host
```

### Advanced: Time-Based Queries

```spl
index=claude_logs earliest=-1h latest=now | tail 100
```

### Advanced: API Access

```bash
curl -k -u admin:password \
  "https://localhost:8089/services/search/jobs" \
  -d "search=index=claude_logs"
```

## Documentation Cross-References

All docs now properly reference Claude logs feature:

- QUICK_START → INSTALLATION (Step 9) → ARCHITECTURE (Section 4)
- API_REFERENCE → Testing Claude logs with REST API
- TROUBLESHOOTING → Debugging missing/stopped logs
- DEVELOPER_GUIDE → Extending log monitoring to other sources

## Key Documentation Principles Applied

✅ **Actionable First**: Show what to search for before explaining how  
✅ **Progressive Complexity**: Basic → Advanced → API access  
✅ **Problem Solving**: Added debugging section for common issues  
✅ **Extensibility**: Documented pattern for adding custom log indexes  
✅ **Cross-References**: Linked related sections instead of duplicating

## Next Steps for Users

1. Run `make up` to initialize Splunk with Claude logs index
2. Query `index=claude_logs` in Splunk Web UI to see Claude activity
3. Reference API_REFERENCE.md for advanced search queries
4. Refer to TROUBLESHOOTING.md if logs aren't appearing

## Pre-Requisites Met

✅ Claude logs directory exists: `~/Library/Logs/Claude/`  
✅ Docker volume mounting configured in compose.yml  
✅ Index creation automated in setup-splunk-user.sh  
✅ Monitor input configured in setup-splunk-user.sh  
✅ Documentation comprehensive across all 6 doc files
