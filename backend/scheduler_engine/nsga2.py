import logging
from typing import List
import random

logger = logging.getLogger("uvicorn.error")
from backend.scheduler_engine.initialization import generate_random_schedule
from backend.scheduler_engine.constraints import constraint_violation
from backend.scheduler_engine.objectives import compute_objectives

def crosses_day_boundary(start, duration, slot_day_map, total_slots):
    if start + duration > total_slots: return True
    start_day = slot_day_map[start]
    if slot_day_map.get(start + duration - 1) != start_day: return True
    return False

def crosses_lunch_break(start_slot, duration, slot_period_map, total_slots):
    if start_slot + duration > total_slots: return True
    # period_number is 1-indexed: P4=4, P5=5
    p_start = slot_period_map[start_slot]
    p_end = slot_period_map[start_slot + duration - 1]
    return p_start <= 4 and p_end >= 5

class Individual:
    def __init__(self, chromosome):
        self.chromosome = chromosome
        self.violation = None
        self.objectives = None
        self.rank = None
        self.crowding_distance = 0

def evaluate(ind, enrollments, teachers, classrooms, subjects, groups, group_conflicts, total_slots, slot_day_map, slot_period_map):
    v, breakdown = constraint_violation(ind.chromosome, enrollments, teachers, classrooms, groups, subjects, group_conflicts, total_slots, slot_day_map, slot_period_map, return_breakdown=True)
    ind.violation = v
    ind.objectives = compute_objectives(ind.chromosome, enrollments, teachers, classrooms, groups, slot_day_map, slot_period_map)
    return ind

def dominates(a, b):
    if a.violation != b.violation: return a.violation < b.violation
    better_or_equal = True
    for i in range(len(a.objectives)):
        if a.objectives[i] > b.objectives[i]: better_or_equal = False
        elif a.objectives[i] < b.objectives[i]: strictly_better = True
    return better_or_equal

def fast_non_dominated_sort(population):
    fronts = [[]]
    dom_count = {p: 0 for p in population}
    dominated = {p: [] for p in population}
    for p in population:
        for q in population:
            if dominates(p, q): dominated[p].append(q)
            elif dominates(q, p): dom_count[p] += 1
        if dom_count[p] == 0:
            p.rank = 0
            fronts[0].append(p)
    i = 0
    while fronts[i]:
        next_front = []
        for p in fronts[i]:
            for q in dominated[p]:
                dom_count[q] -= 1
                if dom_count[q] == 0: q.rank = i + 1; next_front.append(q)
        i += 1
        fronts.append(next_front)
    fronts.pop()
    return fronts

def calculate_crowding_distance(front):
    if not front: return
    num_obj = len(front[0].objectives)
    for ind in front: ind.crowding_distance = 0
    for m in range(num_obj):
        front.sort(key=lambda x: x.objectives[m])
        front[0].crowding_distance = float("inf")
        front[-1].crowding_distance = float("inf")
        min_v, max_v = front[0].objectives[m], front[-1].objectives[m]
        if max_v == min_v: continue
        for i in range(1, len(front) - 1):
            front[i].crowding_distance += (front[i+1].objectives[m] - front[i-1].objectives[m]) / (max_v - min_v)

def tournament_selection(population):
    if len(population) < 2:
        return population[0] if population else None
    a, b = random.sample(population, 2)
    if a.rank < b.rank: return a
    if b.rank < a.rank: return b
    return a if a.crowding_distance > b.crowding_distance else b

def crossover(p1, p2):
    size = len(p1.chromosome)
    if size < 2:
        return Individual(p1.chromosome[:])
    pt1, pt2 = sorted(random.sample(range(size), 2))
    child_chrom = p1.chromosome[:pt1] + p2.chromosome[pt1:pt2] + p1.chromosome[pt2:]
    return Individual(child_chrom)

def repair(chromosome, classrooms, teachers, groups, enrollments, subjects, group_conflicts, total_slots, slot_day_map, slot_period_map, shuffle_genes=True, cancel_event=None):
    repaired = []
    # Occupancy maps for O(1) check
    # (id, slot) -> bool
    room_occ = set()    # (r_id, slot)
    teacher_occ = set() # (t_id, slot)
    group_occ = set()   # (g_id, slot)
    
    enr_day_tracker = set() # (enrollment_id, day)
    
    indexed = list(enumerate(chromosome))
    if shuffle_genes:
        # Shuffle FIRST to ensure diversity within tiers
        random.shuffle(indexed)
        
    # STABLE SORT (Python's .sort is stable, so original shuffle order is kept within tiers)
    # Most-constrained teachers first
    indexed.sort(key=lambda x: len(teachers[enrollments[x[1][0]].teacher_id].available_slots))
    
    repaired_indexed = []
    
    rooms_list = list(classrooms.values())
    
    for orig_idx, gene in indexed:
        if cancel_event and cancel_event.is_set():
            return chromosome # Returning partial or original if cancelled
        found = False
        e_idx, r_id, start_t, dur = gene
        en = enrollments[e_idx]
        t_id, g_id, s_id = en.teacher_id, en.group_id, en.subject_id
        subject = subjects[s_id]
        conflicting_groups = group_conflicts.get(g_id, set())

        valid_rooms = [r.room_id for r in rooms_list if r.room_type == subject.subject_type]
        avail_slots = list(teachers[t_id].available_slots)
        
        # Optimize: shuffle only once per gene repair
        random.shuffle(avail_slots)
        random.shuffle(valid_rooms)
        
        # PASS 1: Ideal — No lunch cross, No same-day, No hard conflicts
        for new_t in avail_slots:
            if new_t + dur > total_slots: continue
            if crosses_day_boundary(new_t, dur, slot_day_map, total_slots): continue
            if crosses_lunch_break(new_t, dur, slot_period_map, total_slots): continue
            if (en.enrollment_id, slot_day_map[new_t]) in enr_day_tracker: continue
            
            possible_range = range(new_t, new_t + dur)
            if any((t_id, ts) in teacher_occ for ts in possible_range): continue
            if any((g_id, ts) in group_occ or any((cg, ts) in group_occ for cg in conflicting_groups) for ts in possible_range): continue
            
            for new_r in valid_rooms:
                if not any((new_r, ts) in room_occ for ts in possible_range):
                    chosen_t, chosen_r = new_t, new_r
                    found = True; break
            if found: break

        # PASS 2: Accept Same-day duplicate, still No Lunch cross, No hard conflicts
        if not found:
            for new_t in avail_slots:
                if new_t + dur > total_slots: continue
                if crosses_day_boundary(new_t, dur, slot_day_map, total_slots): continue
                if crosses_lunch_break(new_t, dur, slot_period_map, total_slots): continue
                # Allow same-day duplicate here
                
                possible_range = range(new_t, new_t + dur)
                if any((t_id, ts) in teacher_occ for ts in possible_range): continue
                if any((g_id, ts) in group_occ or any((cg, ts) in group_occ for cg in conflicting_groups) for ts in possible_range): continue
                
                for new_r in valid_rooms:
                    if not any((new_r, ts) in room_occ for ts in possible_range):
                        chosen_t, chosen_r = new_t, new_r
                        found = True; break
                if found: break

        # PASS 3: Removed (was 'Accept Lunch Cross')
        # We now skip directly to fallback if no contiguous slot is found.

        # FALLBACK 2: Extreme (Random but avoid same-day duplicates AND lunch cross AND day cross)
        if not found:
            backups = [
                s for s in avail_slots 
                if (en.enrollment_id, slot_day_map[s]) not in enr_day_tracker 
                and s + dur <= total_slots
                and not crosses_lunch_break(s, dur, slot_period_map, total_slots)
                and not crosses_day_boundary(s, dur, slot_day_map, total_slots)
            ]
            # If still absolutely trapped, fallback safely avoiding bounds
            safe_avail = [s for s in avail_slots if s + dur <= total_slots and not crosses_day_boundary(s, dur, slot_day_map, total_slots)]
            chosen_t = random.choice(backups) if backups else (random.choice(safe_avail) if safe_avail else start_t)
            
            # Absolute hard cap for safety so it doesn't overrun the day boundary
            if crosses_day_boundary(chosen_t, dur, slot_day_map, total_slots):
                chosen_t -= (dur - 1)

            chosen_r = random.choice(valid_rooms) if valid_rooms else r_id

        # Update O(1) Occupancy
        actual_range = range(chosen_t, chosen_t + dur)
        for ts in actual_range:
            teacher_occ.add((t_id, ts))
            group_occ.add((g_id, ts))
            room_occ.add((chosen_r, ts))
        enr_day_tracker.add((en.enrollment_id, slot_day_map[chosen_t]))
        
        repaired_indexed.append((orig_idx, (e_idx, chosen_r, chosen_t, dur)))

    repaired_indexed.sort(key=lambda x: x[0])
    return [g for _, g in repaired_indexed]

def mutate(individual, enrollments, teachers, classrooms, subjects, groups, group_conflicts, total_slots, slot_day_map, slot_period_map, mutation_rate=0.15):
    chromosome = individual.chromosome[:]
    size = len(chromosome)
    if random.random() < 0.2 and size >= 2:
        i1, i2 = random.sample(range(size), 2)
        g1, g2 = list(chromosome[i1]), list(chromosome[i2])
        g1[1], g1[2], g2[1], g2[2] = g2[1], g2[2], g1[1], g1[2]
        chromosome[i1], chromosome[i2] = tuple(g1), tuple(g2)
    for i in range(size):
        if random.random() > mutation_rate: continue
        eid, old_r, old_t, dur = chromosome[i]
        valid_r = [rid for rid, r in classrooms.items() if r.room_type == subjects[enrollments[eid].subject_id].subject_type]
        # Filter available slots to ONLY those that don't cross lunch or day boundary
        avail = [s for s in teachers[enrollments[eid].teacher_id].available_slots if not crosses_lunch_break(s, dur, slot_period_map, total_slots) and not crosses_day_boundary(s, dur, slot_day_map, total_slots) and s + dur <= total_slots]
        roll = random.random()
        if avail and roll < 0.4: new_t = random.choice(avail)
        elif roll < 0.7: 
            # Try a local shift, but keep only if it doesn't cross lunch AND stays in bounds
            new_t = max(0, min(total_slots-dur, old_t + random.randint(-4,4)))
            if crosses_lunch_break(new_t, dur, slot_period_map, total_slots) or crosses_day_boundary(new_t, dur, slot_day_map, total_slots):
                new_t = old_t # Reset to old if invalid
        else: 
            new_t = random.choice(avail) if avail else old_t
        
        # FINAL BOUNDARY SAFETY
        if new_t + dur > total_slots or crosses_day_boundary(new_t, dur, slot_day_map, total_slots):
            new_t = old_t
            if new_t + dur > total_slots or crosses_day_boundary(new_t, dur, slot_day_map, total_slots):
                 # Extreme fallback if even old_t is totally invalid somehow
                 new_t -= (dur - 1)
                 
        chromosome[i] = (eid, random.choice(valid_r) if valid_r else old_r, new_t, dur)
    return Individual(chromosome)

def run_nsga2(population_size, generations, enrollments, teachers, classrooms, subjects, groups, group_conflicts, total_slots, slot_day_map, slot_period_map, cancel_event=None, progress_callback=None):
    pop = [
        Individual(generate_random_schedule(enrollments, teachers, classrooms, subjects, groups, total_slots, slot_day_map, slot_period_map))
        for _ in range(population_size)
    ]
    found_feasible = False
    for i, ind in enumerate(pop):
        if cancel_event and cancel_event.is_set(): break
        
        if (i + 1) % 20 == 0 or i == 0:
            logger.info(f"  Initializing Population: {i+1}/{population_size}...")
            
        ind.chromosome = repair(ind.chromosome, classrooms, teachers, groups, enrollments, subjects, group_conflicts, total_slots, slot_day_map, slot_period_map, cancel_event=cancel_event)
        evaluate(ind, enrollments, teachers, classrooms, subjects, groups, group_conflicts, total_slots, slot_day_map, slot_period_map)
        
    for gen in range(generations):
        if cancel_event and cancel_event.is_set():
            logger.info(f"  [CANCELLED] Stopping NSGA-II early at Gen {gen}")
            break
            
        fronts = fast_non_dominated_sort(pop)
        for f in fronts: calculate_crowding_distance(f)
        off = []
        while len(off) < population_size:
            if cancel_event and cancel_event.is_set(): break
            p1, p2 = tournament_selection(pop), tournament_selection(pop)
            c = crossover(p1, p2)
            c = mutate(c, enrollments, teachers, classrooms, subjects, groups, group_conflicts, total_slots, slot_day_map, slot_period_map, 0.15 if not found_feasible else 0.3)
            # Always repair to maintain hard constraints
            c.chromosome = repair(c.chromosome, classrooms, teachers, groups, enrollments, subjects, group_conflicts, total_slots, slot_day_map, slot_period_map, cancel_event=cancel_event)
            off.append(evaluate(c, enrollments, teachers, classrooms, subjects, groups, group_conflicts, total_slots, slot_day_map, slot_period_map))
        pop.extend(off)
        fronts = fast_non_dominated_sort(pop)
        new_pop = []
        for f in fronts:
            calculate_crowding_distance(f)
            f.sort(key=lambda x: (x.rank, -x.crowding_distance))
            for ind in f:
                if len(new_pop) < population_size: new_pop.append(ind)
        pop = new_pop
        best = min(pop, key=lambda x: (x.rank, -x.crowding_distance))
        if best.violation == 0 and not found_feasible:
            logger.info(f"  [FEASIBLE] V=0 reached at Gen {gen+1}")
            found_feasible = True
            
        if progress_callback:
            progress_callback(gen, best.violation, best.chromosome)
        
        if (gen + 1) % 10 == 0:
            logger.info(f"  Gen {gen+1:4} | V={best.violation:5} | "
                  f"SG={best.objectives[0]:.3f} | TG={best.objectives[1]:.3f} | "
                  f"RW={best.objectives[2]:.3f} | TD={best.objectives[3]:.3f} | "
                  f"SD={best.objectives[4]:.3f}")
    return pop