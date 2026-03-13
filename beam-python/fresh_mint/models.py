import json
from dataclasses import dataclass, asdict
from datetime import datetime

@dataclass
class Event:
    id: str
    timestamp: str  # ISO-8601 string
    value: float

    @classmethod
    def from_json(cls, json_str: str):
        data = json.loads(json_str)
        return cls(**data)

    def to_dict(self):
        return asdict(self)

    def to_json(self):
        return json.dumps(self.to_dict())

@dataclass
class WindowResult:
    key: str
    value: float
    windowStart: str  # ISO-8601 string
    windowEnd: str    # ISO-8601 string
    windowType: str

    def to_dict(self):
        return asdict(self)

    def to_json(self):
        return json.dumps(self.to_dict())
