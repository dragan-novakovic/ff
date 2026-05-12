use serde::{Deserialize, Serialize};
use std::fmt;

pub const DEFAULT_ROUNDS: u8 = 1;
pub const ENERGY_COST_PER_ROUND: u32 = 10;
pub const MAX_ENERGY: u32 = 100;
pub const MAX_ROUNDS: u8 = 25;
pub const MIN_WEAPON_POWER: u8 = 1;
pub const MAX_WEAPON_POWER: u8 = 5;

#[derive(Debug, Clone, Copy, Serialize, PartialEq, Eq)]
pub struct CombatMission {
    pub mission_id: &'static str,
    pub name: &'static str,
    pub description: &'static str,
    pub defender: Fighter,
    pub rounds: u8,
    pub reward_experience: u32,
    pub reward_gold: u32,
}

#[derive(Debug, Clone, Copy, Deserialize, Serialize, PartialEq, Eq)]
pub struct Fighter {
    pub strength: u32,
    pub energy: u32,
    pub weapon_power: u8,
}

#[derive(Debug, Clone, Copy, Deserialize, Serialize, PartialEq, Eq)]
pub struct FightRequest {
    pub attacker: Fighter,
    pub defender: Fighter,
    pub rounds: Option<u8>,
}

#[derive(Debug, Clone, Copy, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum FightWinner {
    Attacker,
    Defender,
    Draw,
}

#[derive(Debug, Clone, Copy, Deserialize, Serialize, PartialEq, Eq)]
pub struct FightResponse {
    pub winner: FightWinner,
    pub rounds_requested: u8,
    pub rounds_completed: u8,
    pub attacker_damage: u32,
    pub defender_damage: u32,
    pub attacker_remaining_energy: u32,
    pub defender_remaining_energy: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CombatSide {
    Attacker,
    Defender,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FightError {
    InvalidEnergy { side: CombatSide, energy: u32 },
    InvalidRounds { rounds: u8 },
    InvalidWeaponPower { side: CombatSide, weapon_power: u8 },
}

pub fn simulate_fight(request: FightRequest) -> Result<FightResponse, FightError> {
    let rounds = request.rounds.unwrap_or(DEFAULT_ROUNDS);

    validate_rounds(rounds)?;
    validate_fighter(CombatSide::Attacker, request.attacker)?;
    validate_fighter(CombatSide::Defender, request.defender)?;

    let mut attacker_energy = request.attacker.energy;
    let mut defender_energy = request.defender.energy;
    let mut attacker_damage = 0_u32;
    let mut defender_damage = 0_u32;
    let mut rounds_completed = 0_u8;

    for _ in 0..rounds {
        if attacker_energy == 0 && defender_energy == 0 {
            break;
        }

        attacker_damage =
            attacker_damage.saturating_add(damage_for(request.attacker, attacker_energy));
        defender_damage =
            defender_damage.saturating_add(damage_for(request.defender, defender_energy));

        attacker_energy = attacker_energy.saturating_sub(ENERGY_COST_PER_ROUND);
        defender_energy = defender_energy.saturating_sub(ENERGY_COST_PER_ROUND);
        rounds_completed += 1;
    }

    let winner = match attacker_damage.cmp(&defender_damage) {
        std::cmp::Ordering::Greater => FightWinner::Attacker,
        std::cmp::Ordering::Less => FightWinner::Defender,
        std::cmp::Ordering::Equal => FightWinner::Draw,
    };

    Ok(FightResponse {
        winner,
        rounds_requested: rounds,
        rounds_completed,
        attacker_damage,
        defender_damage,
        attacker_remaining_energy: attacker_energy,
        defender_remaining_energy: defender_energy,
    })
}

pub fn missions() -> Vec<CombatMission> {
    vec![
        CombatMission {
            mission_id: "training-bandits",
            name: "Training Bandits",
            description: "A low-risk skirmish for new citizens.",
            defender: Fighter {
                strength: 8,
                energy: 80,
                weapon_power: 1,
            },
            rounds: 3,
            reward_experience: 15,
            reward_gold: 5,
        },
        CombatMission {
            mission_id: "border-raid",
            name: "Border Raid",
            description: "A tougher fight against an organized patrol.",
            defender: Fighter {
                strength: 14,
                energy: 100,
                weapon_power: 2,
            },
            rounds: 5,
            reward_experience: 35,
            reward_gold: 12,
        },
        CombatMission {
            mission_id: "dockside-sweep",
            name: "Dockside Sweep",
            description: "Clear smugglers from a contested harbor warehouse.",
            defender: Fighter {
                strength: 11,
                energy: 90,
                weapon_power: 1,
            },
            rounds: 4,
            reward_experience: 24,
            reward_gold: 8,
        },
        CombatMission {
            mission_id: "safehouse-raid",
            name: "Safehouse Raid",
            description: "Storm a hidden cell before its operatives scatter.",
            defender: Fighter {
                strength: 16,
                energy: 100,
                weapon_power: 2,
            },
            rounds: 5,
            reward_experience: 45,
            reward_gold: 16,
        },
        CombatMission {
            mission_id: "black-market-bust",
            name: "Black Market Bust",
            description: "Break up an illegal arms exchange in the industrial quarter.",
            defender: Fighter {
                strength: 19,
                energy: 100,
                weapon_power: 3,
            },
            rounds: 6,
            reward_experience: 62,
            reward_gold: 24,
        },
        CombatMission {
            mission_id: "convoy-ambush",
            name: "Convoy Ambush",
            description: "Hit a protected supply convoy before it reaches the front.",
            defender: Fighter {
                strength: 23,
                energy: 100,
                weapon_power: 3,
            },
            rounds: 7,
            reward_experience: 84,
            reward_gold: 34,
        },
        CombatMission {
            mission_id: "fortress-breach",
            name: "Fortress Breach",
            description: "Push through a fortified checkpoint guarded by veterans.",
            defender: Fighter {
                strength: 28,
                energy: 100,
                weapon_power: 4,
            },
            rounds: 8,
            reward_experience: 110,
            reward_gold: 48,
        },
        CombatMission {
            mission_id: "warlord-showdown",
            name: "Warlord Showdown",
            description: "Challenge a regional commander in a high-risk boss fight.",
            defender: Fighter {
                strength: 36,
                energy: 100,
                weapon_power: 5,
            },
            rounds: 10,
            reward_experience: 160,
            reward_gold: 75,
        },
    ]
}

pub fn find_mission(mission_id: &str) -> Option<CombatMission> {
    missions()
        .into_iter()
        .find(|mission| mission.mission_id.eq_ignore_ascii_case(mission_id))
}

fn validate_rounds(rounds: u8) -> Result<(), FightError> {
    if rounds == 0 || rounds > MAX_ROUNDS {
        return Err(FightError::InvalidRounds { rounds });
    }

    Ok(())
}

fn validate_fighter(side: CombatSide, fighter: Fighter) -> Result<(), FightError> {
    if fighter.energy > MAX_ENERGY {
        return Err(FightError::InvalidEnergy {
            side,
            energy: fighter.energy,
        });
    }

    if !(MIN_WEAPON_POWER..=MAX_WEAPON_POWER).contains(&fighter.weapon_power) {
        return Err(FightError::InvalidWeaponPower {
            side,
            weapon_power: fighter.weapon_power,
        });
    }

    Ok(())
}

fn damage_for(fighter: Fighter, current_energy: u32) -> u32 {
    if current_energy == 0 || fighter.strength == 0 {
        return 0;
    }

    let energy_used = current_energy.min(ENERGY_COST_PER_ROUND) as u64;
    let weapon_multiplier = 100_u64 + u64::from(fighter.weapon_power) * 20;
    let damage = u64::from(fighter.strength) * energy_used * weapon_multiplier / 1_000;

    damage.min(u64::from(u32::MAX)) as u32
}

impl fmt::Display for CombatSide {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            CombatSide::Attacker => f.write_str("attacker"),
            CombatSide::Defender => f.write_str("defender"),
        }
    }
}

impl fmt::Display for FightError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            FightError::InvalidEnergy { side, energy } => write!(
                f,
                "{side} energy must be between 0 and {MAX_ENERGY}; received {energy}"
            ),
            FightError::InvalidRounds { rounds } => write!(
                f,
                "rounds must be between 1 and {MAX_ROUNDS}; received {rounds}"
            ),
            FightError::InvalidWeaponPower { side, weapon_power } => write!(
                f,
                "{side} weapon_power must be between {MIN_WEAPON_POWER} and {MAX_WEAPON_POWER}; received {weapon_power}"
            ),
        }
    }
}

impl std::error::Error for FightError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn simulates_deterministic_attacker_win() {
        let outcome = simulate_fight(FightRequest {
            attacker: Fighter {
                strength: 80,
                energy: 100,
                weapon_power: 3,
            },
            defender: Fighter {
                strength: 60,
                energy: 100,
                weapon_power: 1,
            },
            rounds: Some(3),
        })
        .expect("fight should be valid");

        assert_eq!(outcome.winner, FightWinner::Attacker);
        assert_eq!(outcome.rounds_requested, 3);
        assert_eq!(outcome.rounds_completed, 3);
        assert_eq!(outcome.attacker_damage, 384);
        assert_eq!(outcome.defender_damage, 216);
        assert_eq!(outcome.attacker_remaining_energy, 70);
        assert_eq!(outcome.defender_remaining_energy, 70);
    }

    #[test]
    fn zero_energy_fighter_deals_no_damage() {
        let outcome = simulate_fight(FightRequest {
            attacker: Fighter {
                strength: 120,
                energy: 0,
                weapon_power: 5,
            },
            defender: Fighter {
                strength: 50,
                energy: 20,
                weapon_power: 2,
            },
            rounds: Some(3),
        })
        .expect("zero energy is allowed");

        assert_eq!(outcome.winner, FightWinner::Defender);
        assert_eq!(outcome.rounds_completed, 2);
        assert_eq!(outcome.attacker_damage, 0);
        assert_eq!(outcome.defender_damage, 140);
        assert_eq!(outcome.attacker_remaining_energy, 0);
        assert_eq!(outcome.defender_remaining_energy, 0);
    }

    #[test]
    fn rejects_invalid_weapon_power() {
        let error = simulate_fight(FightRequest {
            attacker: Fighter {
                strength: 80,
                energy: 100,
                weapon_power: 0,
            },
            defender: Fighter {
                strength: 60,
                energy: 100,
                weapon_power: 1,
            },
            rounds: Some(1),
        })
        .expect_err("weapon power zero should be invalid");

        assert_eq!(
            error,
            FightError::InvalidWeaponPower {
                side: CombatSide::Attacker,
                weapon_power: 0
            }
        );
    }

    #[test]
    fn mission_catalog_contains_progression_jobs() {
        let missions = missions();

        assert!(
            missions.len() >= 8,
            "expected a full job-board catalog, got {} missions",
            missions.len()
        );

        let mut ids = std::collections::HashSet::new();
        for mission in missions {
            assert!(ids.insert(mission.mission_id), "duplicate mission id");
            assert!(!mission.name.trim().is_empty());
            assert!(!mission.description.trim().is_empty());
            assert!((1..=MAX_ROUNDS).contains(&mission.rounds));
            validate_fighter(CombatSide::Defender, mission.defender)
                .expect("catalog defender should be valid");
            assert!(mission.reward_experience > 0);
            assert!(mission.reward_gold > 0);
        }
    }

    #[test]
    fn finds_new_missions_case_insensitively() {
        let mission = find_mission("WARLORD-SHOWDOWN").expect("mission should exist");

        assert_eq!(mission.mission_id, "warlord-showdown");
        assert_eq!(mission.defender.weapon_power, 5);
    }
}
