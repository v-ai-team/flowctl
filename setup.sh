#!/usr/bin/env bash
# ============================================================
# IT Product Team Workflow — Auto Setup
# Cài đặt Graphify, GitNexus và cấu hình MCP servers
# Chạy: bash setup.sh [--mcp-only | --index-only]
# ============================================================

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $*"; }
info() { echo -e "${CYAN}[→]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*"; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-all}"

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   IT Product Team Workflow — Setup Script${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# ── 1. Check prerequisites ───────────────────────────────────
check_prerequisites() {
  info "Kiểm tra prerequisites..."

  command -v python3 &>/dev/null || err "Python 3 chưa được cài. Cài tại: https://python.org"
  command -v pip    &>/dev/null || command -v pip3 &>/dev/null \
    || err "pip chưa được cài. Chạy: python3 -m ensurepip"
  command -v node   &>/dev/null || warn "Node.js chưa được cài — GitNexus MCP sẽ bị skip"
  command -v npm    &>/dev/null || warn "npm chưa được cài — GitNexus MCP sẽ bị skip"

  log "Prerequisites OK"
}

# ── 2. Install Graphify ──────────────────────────────────────
install_graphify() {
  info "Cài đặt Graphify (codebase knowledge graph)..."

  # Thử import trước — nếu đã có thì skip
  if python3 -c "import graphify" &>/dev/null; then
    log "Graphify đã được cài (skip)"
    return 0
  fi

  pip install graphifyy --quiet \
    || pip3 install graphifyy --quiet \
    || err "Không thể cài Graphify. Chạy thủ công: pip install graphifyy"

  log "Graphify đã cài xong"
}

# ── 3. Install GitNexus ──────────────────────────────────────
install_gitnexus() {
  if ! command -v node &>/dev/null; then
    warn "Bỏ qua GitNexus (Node.js không có sẵn)"
    return 0
  fi

  info "Cài đặt GitNexus (code intelligence engine)..."

  if npx gitnexus --version &>/dev/null 2>&1; then
    log "GitNexus đã được cài (skip)"
    return 0
  fi

  # GitNexus chạy qua npx, không cần global install
  npm install --prefix "$REPO_ROOT/.gitnexus" gitnexus 2>/dev/null \
    || warn "npm install gitnexus thất bại — sẽ dùng npx gitnexus khi cần"

  log "GitNexus sẵn sàng (qua npx)"
}

# ── 4. Index codebase với Graphify ───────────────────────────
index_codebase() {
  info "Đang index codebase với Graphify..."

  cd "$REPO_ROOT"

  # Build knowledge graph và export ra .graphify/
  python3 -m graphify index . \
    --output ".graphify/graph.json" \
    --format json \
    2>/dev/null \
    && log "Graphify index hoàn thành → .graphify/graph.json" \
    || warn "graphify index thất bại — sẽ build lại khi chạy MCP server"
}

# ── 5. Tạo .cursor/mcp.json ──────────────────────────────────
configure_cursor_mcp() {
  info "Cấu hình Cursor MCP servers..."

  CURSOR_DIR="$REPO_ROOT/.cursor"
  mkdir -p "$CURSOR_DIR"

  # Chỉ ghi nếu chưa có hoặc user dùng --mcp-only
  if [[ -f "$CURSOR_DIR/mcp.json" && "$MODE" != "--mcp-only" ]]; then
    warn ".cursor/mcp.json đã tồn tại (skip). Dùng --mcp-only để force ghi đè"
    return 0
  fi

  cat > "$CURSOR_DIR/mcp.json" << 'EOF'
{
  "mcpServers": {
    "graphify": {
      "command": "python3",
      "args": ["-m", "graphify.serve", "--root", "."],
      "env": {
        "GRAPHIFY_GRAPH_PATH": ".graphify/graph.json",
        "GRAPHIFY_AUTO_INDEX": "true"
      },
      "description": "Codebase knowledge graph — hiểu cấu trúc, dependencies, clusters"
    },
    "gitnexus": {
      "command": "npx",
      "args": ["gitnexus", "--mcp", "--repo", "."],
      "env": {
        "GITNEXUS_AUTO_INDEX": "true"
      },
      "description": "Code intelligence engine — 16 MCP tools, git diff awareness"
    },
    "flowctl-state": {
      "command": "node",
      "args": [".claude/mcp-flowctl-state.js"],
      "description": "Workflow state tracker — current step, approvals, blockers"
    }
  }
}
EOF

  log ".cursor/mcp.json đã được tạo"
}

# ── 6. Tạo .gitignore entries ────────────────────────────────
update_gitignore() {
  GITIGNORE="$REPO_ROOT/.gitignore"

  info "Cập nhật .gitignore..."

  # Tạo nếu chưa có
  [[ -f "$GITIGNORE" ]] || touch "$GITIGNORE"

  # Thêm entries nếu chưa có
  local entries=(
    ".graphify/cache/"
    ".gitnexus/"
    "node_modules/"
    "__pycache__/"
    "*.pyc"
    ".env"
    ".env.local"
  )

  for entry in "${entries[@]}"; do
    grep -qxF "$entry" "$GITIGNORE" || echo "$entry" >> "$GITIGNORE"
  done

  # Nhưng track graph output
  grep -qxF "!.graphify/graph.json" "$GITIGNORE" \
    || echo "!.graphify/graph.json" >> "$GITIGNORE"

  log ".gitignore đã cập nhật"
}

# ── 7. Khởi động MCP servers (background) ───────────────────
start_mcp_servers() {
  info "Khởi động MCP servers..."

  # Graphify MCP server
  if python3 -c "import graphify" &>/dev/null; then
    python3 -m graphify.serve --root "$REPO_ROOT" \
      --port 7331 --background 2>/dev/null \
      && log "Graphify MCP server đang chạy tại :7331" \
      || warn "Graphify MCP server không tự khởi động — Cursor sẽ tự start khi cần"
  fi

  log "MCP servers đã được cấu hình. Cursor sẽ tự khởi động khi cần."
}

# ── 8. Summary ───────────────────────────────────────────────
print_summary() {
  echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}   Setup hoàn thành!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "  ${CYAN}Bước tiếp theo:${NC}"
  echo -e "  1. Mở Cursor và reload window (Cmd/Ctrl+Shift+P → Reload)"
  echo -e "  2. Kiểm tra MCP servers: Cursor → Settings → MCP"
  echo -e "  3. Bắt đầu flowctl: ${YELLOW}flowctl start${NC}"
  echo -e "  4. Xem trạng thái:   ${YELLOW}flowctl status${NC}"
  echo ""
  echo -e "  ${CYAN}Files quan trọng:${NC}"
  echo -e "  • CLAUDE.md          — Orchestration guide cho agents"
  echo -e "  • flowctl-state.json — Trạng thái flowctl hiện tại"
  echo -e "  • .cursor/mcp.json   — MCP server configuration"
  echo -e "  • .graphify/graph.json — Codebase knowledge graph"
  echo ""
}

# ── Main ─────────────────────────────────────────────────────
main() {
  case "$MODE" in
    --mcp-only)
      check_prerequisites
      configure_cursor_mcp
      ;;
    --index-only)
      install_graphify
      index_codebase
      ;;
    all|*)
      check_prerequisites
      install_graphify
      install_gitnexus
      [[ "$MODE" != "--no-index" ]] && index_codebase
      configure_cursor_mcp
      update_gitignore
      start_mcp_servers
      print_summary
      ;;
  esac
}

main "$@"
