#!/usr/bin/env python3
"""
Parallel test script for RISC-V optimizer with both sym and stoch modes.
Tests all programs except mulhu64_soft.s
"""

import os
import sys
import subprocess
import time
import glob
from datetime import datetime
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor, as_completed
from dataclasses import dataclass
from typing import List, Tuple

# Configuration
TIME_LIMIT = 300000  # 5 minutes per test
NUM_CORES = 1     # Number of cores per search mode
MAX_PARALLEL_JOBS = 4  # Maximum number of tests to run in parallel

# ANSI color codes
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    BOLD = '\033[1m'
    NC = '\033[0m'  # No Color

@dataclass
class TestResult:
    program: str
    mode: str
    status: str  # SUCCESS, TIMEOUT, ERROR
    logfile: str
    original_cost: int = None
    new_cost: int = None
    improvement: str = None
    elapsed_time: float = None

def print_header():
    """Print test suite header"""
    print(f"{Colors.BLUE}{'=' * 60}{Colors.NC}")
    print(f"{Colors.BLUE}{Colors.BOLD}RISC-V Optimizer Parallel Test Suite{Colors.NC}")
    print(f"{Colors.BLUE}{'=' * 60}{Colors.NC}")
    print()

def get_test_programs() -> List[str]:
    """Get list of test programs, excluding mulhu64 and test_x0"""
    all_programs = glob.glob("programs/*.s")
    filtered = [
        p for p in all_programs
        if "mulhu64" not in p and "test_x0" not in p
    ]
    return sorted(filtered)

def run_single_test(program: str, mode: str, output_dir: str) -> TestResult:
    """Run a single optimizer test"""
    basename = Path(program).stem
    logfile = os.path.join(output_dir, f"{basename}_{mode}.log")

    print(f"{Colors.YELLOW}[START]{Colors.NC} Testing {basename} with {mode} mode...")

    start_time = time.time()

    try:
        # Run optimizer with timeout
        result = subprocess.run(
            ["racket", "optimize.rkt", f"--{mode}", "-o", "-c", str(NUM_CORES), program],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=TIME_LIMIT,
            text=True
        )

        elapsed = time.time() - start_time

        # Write log file
        with open(logfile, 'w') as f:
            f.write(result.stdout)

        # Parse results
        test_result = TestResult(
            program=basename,
            mode=mode,
            status="SUCCESS",
            logfile=logfile,
            elapsed_time=elapsed
        )

        # Extract metrics from output
        for line in result.stdout.split('\n'):
            if ">>> original cost:" in line:
                test_result.original_cost = int(line.split()[-1])
            elif "New cost:" in line:
                test_result.new_cost = int(line.split()[-1])
            elif "Improvement:" in line:
                test_result.improvement = line.split("Improvement:")[-1].strip()

        if "IMPROVEMENT FOUND" in result.stdout:
            print(f"{Colors.GREEN}[DONE]{Colors.NC} {basename} ({mode}) - {Colors.GREEN}IMPROVEMENT FOUND!{Colors.NC}")
        else:
            print(f"{Colors.GREEN}[DONE]{Colors.NC} {basename} ({mode}) - {elapsed:.1f}s")

        return test_result

    except subprocess.TimeoutExpired:
        elapsed = time.time() - start_time
        print(f"{Colors.YELLOW}[TIMEOUT]{Colors.NC} {basename} ({mode}) - Exceeded {TIME_LIMIT}s")

        # Still write partial log if available
        try:
            with open(logfile, 'w') as f:
                f.write(f"TIMEOUT after {TIME_LIMIT}s\n")
        except:
            pass

        return TestResult(
            program=basename,
            mode=mode,
            status="TIMEOUT",
            logfile=logfile,
            elapsed_time=elapsed
        )

    except Exception as e:
        elapsed = time.time() - start_time
        print(f"{Colors.RED}[ERROR]{Colors.NC} {basename} ({mode}) - {str(e)}")

        # Write error log
        with open(logfile, 'w') as f:
            f.write(f"ERROR: {str(e)}\n")

        return TestResult(
            program=basename,
            mode=mode,
            status="ERROR",
            logfile=logfile,
            elapsed_time=elapsed
        )

def print_summary(results: List[TestResult], output_dir: str):
    """Print test summary"""
    print()
    print(f"{Colors.BLUE}{'=' * 60}{Colors.NC}")
    print(f"{Colors.BLUE}{Colors.BOLD}Test Summary{Colors.NC}")
    print(f"{Colors.BLUE}{'=' * 60}{Colors.NC}")
    print()

    # Count statistics
    success_count = sum(1 for r in results if r.status == "SUCCESS")
    timeout_count = sum(1 for r in results if r.status == "TIMEOUT")
    error_count = sum(1 for r in results if r.status == "ERROR")
    improvement_count = sum(1 for r in results if r.improvement)

    # Group by program
    programs = {}
    for result in results:
        if result.program not in programs:
            programs[result.program] = {}
        programs[result.program][result.mode] = result

    # Print per-program results
    for prog_name in sorted(programs.keys()):
        print(f"{Colors.BLUE}{Colors.BOLD}Program: {prog_name}{Colors.NC}")

        for mode in ['sym', 'stoch']:
            if mode in programs[prog_name]:
                r = programs[prog_name][mode]

                status_str = ""
                if r.status == "SUCCESS":
                    status_str = f"{Colors.GREEN}✓ SUCCESS{Colors.NC}"
                elif r.status == "TIMEOUT":
                    status_str = f"{Colors.YELLOW}⏱ TIMEOUT{Colors.NC}"
                else:
                    status_str = f"{Colors.RED}✗ ERROR{Colors.NC}"

                extra_info = []
                if r.original_cost is not None:
                    extra_info.append(f"cost={r.original_cost}")
                if r.improvement:
                    extra_info.append(f"{Colors.GREEN}IMPROVED: {r.improvement}{Colors.NC}")
                if r.elapsed_time:
                    extra_info.append(f"{r.elapsed_time:.1f}s")

                extra = f" ({', '.join(extra_info)})" if extra_info else ""
                print(f"  {mode:6s}: {status_str}{extra}")
        print()

    # Print overall statistics
    print(f"{Colors.BLUE}{'=' * 60}{Colors.NC}")
    print(f"{Colors.GREEN}Total SUCCESS: {success_count}{Colors.NC}")
    print(f"{Colors.YELLOW}Total TIMEOUT: {timeout_count}{Colors.NC}")
    print(f"{Colors.RED}Total ERROR: {error_count}{Colors.NC}")
    print(f"{Colors.CYAN}Programs with IMPROVEMENTS: {improvement_count}{Colors.NC}")
    print(f"{Colors.BLUE}{'=' * 60}{Colors.NC}")
    print()
    print(f"{Colors.BLUE}Detailed logs available in: {output_dir}/{Colors.NC}")
    print()

    return success_count, timeout_count, error_count, improvement_count

def write_summary_report(results: List[TestResult], output_dir: str):
    """Write summary report to markdown file"""
    summary_file = os.path.join(output_dir, "SUMMARY.md")

    with open(summary_file, 'w') as f:
        f.write("# RISC-V Optimizer Test Summary\n\n")
        f.write(f"**Date**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"**Time Limit**: {TIME_LIMIT}s per test\n")
        f.write(f"**Total Tests**: {len(results)}\n\n")

        # Statistics
        success_count = sum(1 for r in results if r.status == "SUCCESS")
        timeout_count = sum(1 for r in results if r.status == "TIMEOUT")
        error_count = sum(1 for r in results if r.status == "ERROR")
        improvement_count = sum(1 for r in results if r.improvement)

        f.write("## Results\n\n")
        f.write(f"- ✓ Success: {success_count}\n")
        f.write(f"- ⏱ Timeout: {timeout_count}\n")
        f.write(f"- ✗ Error: {error_count}\n")
        f.write(f"- 🎯 Improvements Found: {improvement_count}\n\n")

        # Group by program
        programs = {}
        for result in results:
            if result.program not in programs:
                programs[result.program] = {}
            programs[result.program][result.mode] = result

        f.write("## Program Details\n\n")
        for prog_name in sorted(programs.keys()):
            f.write(f"### {prog_name}\n\n")

            for mode in ['sym', 'stoch']:
                if mode in programs[prog_name]:
                    r = programs[prog_name][mode]
                    f.write(f"**Mode: {mode}**\n")
                    f.write(f"- Status: {r.status}\n")
                    if r.original_cost is not None:
                        f.write(f"- Original Cost: {r.original_cost}\n")
                    if r.new_cost is not None:
                        f.write(f"- New Cost: {r.new_cost}\n")
                    if r.improvement:
                        f.write(f"- Improvement: {r.improvement}\n")
                    if r.elapsed_time:
                        f.write(f"- Time: {r.elapsed_time:.1f}s\n")
                    f.write(f"- Log: {r.logfile}\n\n")
            f.write("\n")

    print(f"{Colors.GREEN}Summary report created: {summary_file}{Colors.NC}")
    print()

def main():
    """Main test execution"""
    print_header()

    # Create output directory
    output_dir = f"test_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    os.makedirs(output_dir, exist_ok=True)
    print(f"{Colors.GREEN}Created output directory: {output_dir}{Colors.NC}")
    print()

    # Get test programs
    programs = get_test_programs()
    print(f"{Colors.BLUE}Programs to test ({len(programs)} total):{Colors.NC}")
    for prog in programs:
        print(f"  - {Path(prog).name}")
    print()

    # Create test jobs
    test_jobs = []
    for prog in programs:
        test_jobs.append((prog, 'sym', output_dir))
        test_jobs.append((prog, 'stoch', output_dir))

    print(f"{Colors.BLUE}Running {len(test_jobs)} tests in parallel...{Colors.NC}")
    print(f"{Colors.BLUE}Time limit per test: {TIME_LIMIT}s{Colors.NC}")
    print(f"{Colors.BLUE}Max parallel jobs: {MAX_PARALLEL_JOBS}{Colors.NC}")
    print()

    # Run tests in parallel
    results = []
    with ProcessPoolExecutor(max_workers=MAX_PARALLEL_JOBS) as executor:
        futures = {
            executor.submit(run_single_test, prog, mode, out_dir): (prog, mode)
            for prog, mode, out_dir in test_jobs
        }

        for future in as_completed(futures):
            try:
                result = future.result()
                results.append(result)
            except Exception as e:
                prog, mode = futures[future]
                print(f"{Colors.RED}[EXCEPTION]{Colors.NC} {prog} ({mode}): {e}")

    # Print summary
    success, timeout, error, improvements = print_summary(results, output_dir)

    # Write summary report
    write_summary_report(results, output_dir)

    # Exit with error if any tests failed
    if error > 0:
        sys.exit(1)

if __name__ == "__main__":
    main()
