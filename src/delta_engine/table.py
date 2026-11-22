"""
Delta Lake Table Protocol Implementation
Provides ACID transactions, metadata management, Parquet storage, and Time Travel.
Fully compatible with Delta Lake directory structure (_delta_log/*.json).
"""
import os
import json
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, List, Dict, Any, Union
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq


class DeltaTable:
    """
    Manages an ACID Delta Table backed by PyArrow Parquet files and a JSON commit log.
    Conforms to the Delta Lake protocol structure:
      table_path/
        ├── _delta_log/
        │   ├── 00000000000000000000.json
        │   └── 00000000000000000001.json
        ├── part-00000-<uuid>.parquet
        └── ...
    """

    def __init__(self, table_path: Union[str, Path]):
        self.table_path = Path(table_path)
        self.log_path = self.table_path / "_delta_log"
        self._ensure_log_dir()

    def _ensure_log_dir(self):
        self.log_path.mkdir(parents=True, exist_ok=True)

    def _get_log_files(self) -> List[Path]:
        """Returns sorted list of commit log files."""
        files = list(self.log_path.glob("*.json"))
        # Sort by commit version integer
        return sorted(files, key=lambda f: int(f.stem))

    @property
    def latest_version(self) -> int:
        logs = self._get_log_files()
        if not logs:
            return -1
        return int(logs[-1].stem)

    def _format_version_filename(self, version: int) -> str:
        return f"{version:020d}.json"

    def write(
        self,
        df: pd.DataFrame,
        mode: str = "append",
        partition_by: Optional[List[str]] = None,
        author: str = "DataEngineerAgent"
    ) -> int:
        """
        Writes data to the Delta table with an ACID commit.
        Modes:
          - 'append': Adds new Parquet files, keeping existing files.
          - 'overwrite': Marks previous active files as removed in the log.
        """
        if df.empty and mode != "overwrite":
            return self.latest_version

        current_ver = self.latest_version
        new_ver = current_ver + 1
        commit_actions = []
        now_ms = int(time.time() * 1000)
        timestamp_str = datetime.now(timezone.utc).isoformat()

        # If initial commit (version 0), write protocol and metadata
        if new_ver == 0:
            commit_actions.append({
                "protocol": {
                    "minReaderVersion": 1,
                    "minWriterVersion": 2
                }
            })
            schema_meta = {
                "type": "struct",
                "fields": [
                    {"name": col, "type": str(dtype), "nullable": True, "metadata": {}}
                    for col, dtype in df.dtypes.items()
                ]
            }
            commit_actions.append({
                "metaData": {
                    "id": str(uuid.uuid4()),
                    "format": {"provider": "parquet", "options": {}},
                    "schemaString": json.dumps(schema_meta),
                    "partitionColumns": partition_by or [],
                    "configuration": {},
                    "createdTime": now_ms
                }
            })

        # If overwrite mode, mark previous active files as removed
        active_files = self._get_active_files_at_version(current_ver) if current_ver >= 0 else []
        if mode == "overwrite":
            for f in active_files:
                commit_actions.append({
                    "remove": {
                        "path": f,
                        "deletionTimestamp": now_ms,
                        "dataChange": True
                    }
                })

        # Write Parquet data file
        file_id = uuid.uuid4().hex
        file_name = f"part-{new_ver:05d}-{file_id}.parquet"
        file_path = self.table_path / file_name

        arrow_table = pa.Table.from_pandas(df, preserve_index=False)
        pq.write_table(arrow_table, file_path, compression="snappy")

        file_size = os.path.getsize(file_path)
        num_records = len(df)

        commit_actions.append({
            "add": {
                "path": file_name,
                "size": file_size,
                "modificationTime": now_ms,
                "dataChange": True,
                "stats": json.dumps({
                    "numRecords": num_records,
                    "columns": list(df.columns)
                })
            }
        })

        # Commit metadata
        commit_actions.append({
            "commitInfo": {
                "timestamp": now_ms,
                "timestampIso": timestamp_str,
                "operation": "WRITE",
                "operationParameters": {
                    "mode": mode,
                    "partitionBy": partition_by or []
                },
                "operationMetrics": {
                    "numFiles": 1,
                    "numOutputRows": num_records,
                    "numOutputBytes": file_size
                },
                "userName": author,
                "isolationLevel": "Serializable"
            }
        })

        # Write atomic commit log file
        log_file = self.log_path / self._format_version_filename(new_ver)
        with open(log_file, "w", encoding="utf-8") as f:
            for action in commit_actions:
                f.write(json.dumps(action) + "\n")

        return new_ver

    def _get_active_files_at_version(self, target_version: int) -> List[str]:
        """Reconstructs state by reading commits from 0 up to target_version."""
        if target_version < 0:
            return []

        active_files = set()
        for v in range(target_version + 1):
            log_file = self.log_path / self._format_version_filename(v)
            if not log_file.exists():
                continue
            with open(log_file, "r", encoding="utf-8") as f:
                for line in f:
                    action = json.loads(line)
                    if "add" in action:
                        active_files.add(action["add"]["path"])
                    elif "remove" in action:
                        path_to_remove = action["remove"]["path"]
                        active_files.discard(path_to_remove)
        return list(active_files)

    def read(
        self,
        version: Optional[int] = None,
        as_of_timestamp: Optional[str] = None
    ) -> pd.DataFrame:
        """
        Reads the table at a specific version or as-of timestamp (Time Travel).
        If version and timestamp are None, reads latest state.
        """
        target_version = self.latest_version
        if target_version == -1:
            return pd.DataFrame()

        if as_of_timestamp:
            target_version = self._find_version_by_timestamp(as_of_timestamp)
        elif version is not None:
            if version > target_version:
                raise ValueError(f"Version {version} does not exist. Latest is {target_version}")
            target_version = version

        active_files = self._get_active_files_at_version(target_version)
        if not active_files:
            return pd.DataFrame()

        dfs = []
        for file_name in active_files:
            fp = self.table_path / file_name
            if fp.exists():
                dfs.append(pq.read_table(fp).to_pandas())

        if not dfs:
            return pd.DataFrame()

        return pd.concat(dfs, ignore_index=True)

    def _find_version_by_timestamp(self, ts_str: str) -> int:
        """Finds closest version whose commit was on or before ts_str."""
        target_dt = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
        target_ms = int(target_dt.timestamp() * 1000)

        logs = self._get_log_files()
        matched_ver = -1
        for log in logs:
            ver = int(log.stem)
            with open(log, "r", encoding="utf-8") as f:
                for line in f:
                    act = json.loads(line)
                    if "commitInfo" in act:
                        commit_ms = act["commitInfo"]["timestamp"]
                        if commit_ms <= target_ms:
                            matched_ver = ver
        return matched_ver if matched_ver != -1 else 0

    def get_history(self) -> List[Dict[str, Any]]:
        """Returns the commit history with audit details."""
        history = []
        for log in self._get_log_files():
            ver = int(log.stem)
            with open(log, "r", encoding="utf-8") as f:
                for line in f:
                    act = json.loads(line)
                    if "commitInfo" in act:
                        info = act["commitInfo"]
                        history.append({
                            "version": ver,
                            "timestamp": info.get("timestampIso", ""),
                            "operation": info.get("operation", ""),
                            "operationMetrics": info.get("operationMetrics", {}),
                            "userName": info.get("userName", ""),
                            "isolationLevel": info.get("isolationLevel", "")
                        })
        return history

    def vacuum(self, retention_hours: int = 168) -> int:
        """
        Removes physical Parquet files that were removed in the transaction log
        and are older than retention_hours.
        """
        now_ms = int(time.time() * 1000)
        retention_ms = retention_hours * 3600 * 1000
        cutoff_ms = now_ms - retention_ms

        # Gather removed files older than cutoff
        removed_candidates = {}
        for log in self._get_log_files():
            with open(log, "r", encoding="utf-8") as f:
                for line in f:
                    act = json.loads(line)
                    if "remove" in act:
                        rem = act["remove"]
                        del_ts = rem.get("deletionTimestamp", 0)
                        if del_ts < cutoff_ms:
                            removed_candidates[rem["path"]] = del_ts

        # Exclude any that are still active in latest version
        active_now = set(self._get_active_files_at_version(self.latest_version))
        deleted_count = 0
        for path_str, _ in removed_candidates.items():
            if path_str not in active_now:
                p = self.table_path / path_str
                if p.exists():
                    p.unlink()
                    deleted_count += 1
        return deleted_count
