## Current Work

Creating a City Block V-Sekai domain simulator that runs the game domain defined in `apps/aria_viewer/decisions/draft_vsekai_domain.exs`. The simulator will execute 4 Bartle taxonomy-based player archetypes adapted for urban community dynamics within a single city block environment, with real-time activity logging through a web interface.

## Key Technical Concepts

- **City Block Game Domain**: 4 Bartle-based archetypes adapted for local community interactions within one contained urban space
- **AriaHybridPlanner.Domain**: Domain definition framework for urban simulation
- **Phoenix Framework**: Web application with real-time capabilities via channels
- **TimescaleDB**: Time-series database for simulation event logging with hypertables
- **AriaState**: State management for block state and agent tracking
- **Multi-agent Simulation**: Concurrent execution of community member agents
- **Block Transfer**: Fast, in-memory state hand-off between local destinations (adapted from zone transfer concept)

## Relevant Files and Code

### Game Domain Definition

- `apps/aria_viewer/decisions/draft_vsekai_domain.exs`: Complete Vsekai.GameDomain with 4 Bartle archetypes
  - Social Explorer → Local Socializer: join_world → socialize → log_social_event
  - World Hopper → Block Explorer: visit_new_world → transfer_to_world (block transfer)
  - Achiever → Local Achiever: refine_resource → process_item for resource accumulation
  - Competitor → Block Competitor: engage_in_combat → record_match_outcome for ranking

### Existing Infrastructure

- `apps/aria_viewer/lib/aria_viewer_web/channels/ik_channel.ex`: Phoenix channel (needs adaptation for simulation)
- `apps/aria_viewer/priv/static/js/app.js`: WebSocket client setup (can be adapted)
- `apps/aria_viewer/mix.exs`: Phoenix dependencies already configured
- `apps/aria_viewer/decisions/timescaledb_optimization.sql`: TimescaleDB setup scripts
- `apps/aria_viewer/decisions/V-Sekai System Architecture Plan.md`: Block transfer concept reference

### Database Optimization Files

- `apps/aria_viewer/decisions/bitemporal_6nf_postgres.sql`: Bitemporal schema reference
- `apps/aria_viewer/decisions/timescaledb_optimization.sql`: Hypertable optimization patterns

## City Block Environment Features

- **Block Map**: Grid-based representation of buildings and streets
- **Business Registry**: Local businesses with owners and specialties
- **Community Events**: Scheduled gatherings and block activities
- **Resource Economy**: Block-level goods and services
- **Social Networks**: Relationship tracking between block residents

## Problem Solving

### Architecture Decisions Made

1. **Reuse aria_viewer**: Leverage existing Phoenix + WebSocket infrastructure
2. **Multi-agent simulation**: Run concurrent agents with different Bartle archetypes
3. **Real-time logging**: Capture all domain actions via Phoenix channels
4. **TimescaleDB integration**: Apply optimizations for simulation event storage
5. **Web dashboard**: Clean interface for simulation monitoring and control
6. **City block ethos**: Single contained environment with local community dynamics
7. **Block transfer**: Fast in-memory state hand-off between local destinations

### Technical Challenges Addressed

- **Domain adaptation**: Move Vsekai.GameDomain to AriaViewer.GameDomain with city block modifications
- **State management**: AriaState.RelationalState for agent and block state
- **Concurrent execution**: Manage multiple agents running simultaneously within block
- **Event streaming**: Real-time broadcasting of simulation activities
- **Performance monitoring**: Track simulation metrics and agent behavior
- **Block transfer implementation**: Fast in-memory movement between local destinations

## Pending Tasks and Next Steps

### Phase 1: Domain Integration & City Block Setup

1. Move Vsekai.GameDomain into AriaViewer.GameDomain namespace
2. Adapt domain methods for city block environment (block transfer vs world hopping)
3. Create city block environment definition (buildings, businesses, locations)
4. Implement agent archetypes for local community setting
5. Set up AriaState integration for block simulation state

### Phase 2: Simulation Engine & Agent Behaviors

1. Create simulation engine for multi-agent execution within city block
2. Implement Social Explorer archetype (cafe visits, neighbor interactions)
3. Implement World Hopper archetype (local discovery, block transfers)
4. Implement Achiever archetype (business success, service provision)
5. Implement Competitor archetype (community leadership, local rivalries)
6. Build agent scheduler for concurrent block resident management

### Phase 3: Real-time Simulation & Broadcasting

1. Implement activity logging for all agent actions with block location metadata
2. Add TimescaleDB integration for event storage with hypertables
3. Create simulation channel for real-time event broadcasting
4. Build simulation controls (start/stop/pause, agent count adjustment)
5. Add performance monitoring and simulation metrics

### Phase 4: Web Simulation Interface

1. Remove 3D IK dependencies and adapt existing channel for simulation
2. Create simulation dashboard for real-time block monitoring
3. Add agent status displays with individual activity tracking
4. Implement web-based simulation controls
5. Build activity visualization with charts and graphs for block dynamics

### Phase 5: Analytics & Community Insights

1. Create simulation analytics for agent behavior patterns
2. Build historical reports using TimescaleDB data
3. Implement archetype analysis and comparison within block context
4. Add performance metrics and system utilization tracking
5. Create data export capabilities for community behavior analysis

## Implementation Strategy

### Core Simulation Loop

- Initialize agents as block residents with different Bartle archetypes
- Execute domain actions based on local goals and community state
- Log all activities with timestamps and block location metadata
- Broadcast events in real-time via WebSockets
- Maintain block state and resident status

### Agent Archetypes Implementation

- **Social Explorer**: Cafe visits → neighbor socialization → community event logging
- **World Hopper**: Local discovery → block transfers → destination exploration
- **Achiever**: Business operations → service provision → community reputation
- **Competitor**: Community leadership → event organization → local influence

### Real-time Architecture

- Phoenix channels for simulation event broadcasting
- WebSocket streaming of block activities and social dynamics
- TimescaleDB for persistent event storage with block-specific metadata
- Dashboard for live community monitoring
- Controls for simulation management within city block context

## Success Criteria

- **Multi-agent simulation**: Successfully run 50+ concurrent block residents
- **Real-time monitoring**: Live dashboard showing block activities and social dynamics
- **Complete domain execution**: All 4 Bartle archetypes functioning with local goal-task chains
- **Block transfer performance**: Zero IOPS for movement within the block (in-memory)
- **TimescaleDB integration**: Efficient storage of community interaction events
- **Web interface**: Intuitive controls and visualization of block community state
- **Performance**: Maintain simulation performance with active community interactions

This city block simulation creates an intimate, observable environment where community dynamics unfold in real-time, with agents forming relationships, competing for local status, and participating in block-level activities. The block transfer mechanism ensures seamless movement between local destinations while maintaining the original architecture's performance benefits.
