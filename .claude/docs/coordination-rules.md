# Agent Coordination Rules

1. **Vertical Delegation**: Leadership agents delegate to department leads, who
   delegate to specialists. Never skip a tier for complex decisions.
2. **Horizontal Consultation**: Agents at the same tier may consult each other
   but must not make binding decisions outside their domain.
3. **Conflict Resolution**: When two agents disagree, escalate to the shared
   parent. If no shared parent, escalate to `creative-director` for design
   conflicts or `technical-director` for technical conflicts.
4. **Change Propagation**: When a design change affects multiple domains, the
   `producer` agent coordinates the propagation.
5. **No Unilateral Cross-Domain Changes**: An agent must never modify files
   outside its designated directories without explicit delegation.
6. **Breaking Change Authorization**: Any change that modifies a public API,
   signal signature, or Resource schema requires explicit approval from
   `lead-programmer` before implementation.
7. **Design-Tech Conflict Protocol**: If a design requirement conflicts with
   a technical constraint, both agents document their position; `technical-director`
   makes the binding decision within one session.
8. **GDD-First Rule**: No implementation agent may write `src/` code for a system
   until the corresponding GDD has been approved and committed. The GDD is the
   contract; code fulfills the contract.
9. **Audit Trail**: Every agent that modifies a GDD or ADR must log the change
   reason as a doc comment or inline note. Silent modifications are forbidden.
