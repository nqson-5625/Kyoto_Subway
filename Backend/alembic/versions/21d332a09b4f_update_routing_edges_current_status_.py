"""update routing_edges_current_status_source_chk

Revision ID: 21d332a09b4f
Revises: e60f35d796c3
Create Date: 2026-05-31 11:38:33.097357

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '21d332a09b4f'
down_revision: Union[str, Sequence[str], None] = 'e60f35d796c3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Bỏ constraint cũ
    op.execute("""
        ALTER TABLE routing_edges_current 
        DROP CONSTRAINT IF EXISTS routing_edges_current_status_source_chk;
    """)
    # Thêm constraint mới
    op.execute("""
        ALTER TABLE routing_edges_current 
        ADD CONSTRAINT routing_edges_current_status_source_chk 
        CHECK (status_source IN (
            'normal', 'edge_event', 'line_current', 'station_current', 
            'scenario', 'delay_event', 'maintenance', 'manual_override'
        ));
    """)

def downgrade() -> None:
    # Rollback về trạng thái cũ nếu cần
    op.execute("""
        ALTER TABLE routing_edges_current 
        DROP CONSTRAINT IF EXISTS routing_edges_current_status_source_chk;
    """)
    op.execute("""
        ALTER TABLE routing_edges_current 
        ADD CONSTRAINT routing_edges_current_status_source_chk 
        CHECK (status_source IN (
            'normal', 'delay_event', 'maintenance', 'manual_override', 'scenario'
        ));
    """)
