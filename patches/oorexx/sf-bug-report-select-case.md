# SourceForge bug report — ready to paste

Tracker: <https://sourceforge.net/p/oorexx/bugs/new/>

| Field | Value |
|---|---|
| **Title** | SELECT CASE: the DoBlock is not protected while the CASE expression is evaluated (heap corruption: crash or hang) |
| **Milestone** | 5.3.0 |
| **Priority** | 7 |
| **Labels** | interpreter, gc |
| **Attachments** | `select-case-gc.diff`, `select-case-repro.rex` |

## Description (Markdown, paste as is)

`RexxInstructionSelectCase::execute` (`interpreter/instructions/SelectInstruction.cpp`) creates the instruction's `DoBlock`, keeps it only in a C++ local, and then evaluates the CASE expression; only after that does `context->newBlockInstruction(doblock)` anchor the block in the activation:

```cpp
DoBlock *doblock = new DoBlock (context, this);
RexxObject *caseResult = caseExpr->evaluate(context, stack);   // may run any code
context->traceKeywordResult(GlobalNames::CASE, caseResult);
context->newBlockInstruction(doblock);
doblock->setCase(caseResult);
```

If the evaluation triggers a garbage collection, nothing references the block, so it is swept, and the activation then uses the swept storage. The object heap is corrupted, and the program later crashes (SIGSEGV / 0xC0000005, typically in `DeadObjectPool::findFit` while allocating, or in an activation's own tables) or hangs (`findFit` looping on a broken free chain), often far from the SELECT. Any CASE expression that allocates is enough: a message to an object whose method runs Rexx code, a string BIF, `x~upper`... Only a plain variable or literal is safe. The plain SELECT does not have the problem (it anchors the block at once); the DO loops protect theirs (`Protected<DoBlock>` in `BaseDoInstruction.cpp`).

**Reproducer** (attached, `select-case-repro.rex`): a loop with `select case o~alpha~beta~name`, where the messages run Rexx methods that allocate. With trunk r13269 (Linux x86_64) it ends with a segmentation fault within a second, every run; on Windows (the 5.3.0 portable build, r13268) we met it as random 0xC0000005 crashes and hangs in a long-running program. With the patch it prints `built 2288895`.

```
$ rexx select-case-repro.rex
Segmentation fault (core dumped)
```

**How we found it**: a program that runs `select case key~GetValueKind(name)~string` (a .NET call through a bridge) ~23,000 times crashed or hung in half of its runs, in the allocator. Dumps of an ooRexx built with symbols (and with `CHECKOREFS`) showed an active activation's tables already swept (its local reference table's slot holding another object, its trap table corrupted); forcing a collection every few hundred allocations made it deterministic, and reduced it to the attached program, which needs nothing but ooRexx.

**Fix** (attached, `select-case-gc.diff`): protect the block and the CASE value while the expression is evaluated, as the DO instructions do:

```cpp
Protected<DoBlock> doblock = new DoBlock (context, this);
ProtectedObject caseResult = caseExpr->evaluate(context, stack);
```

Built and checked on Linux (the reproducer, and the original program under forced collections) and on Windows (the original program).
